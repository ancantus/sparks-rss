let check condition message = if not condition then failwith message

let contains text substring =
  let text_length = String.length text and sub_length = String.length substring in
  let rec loop i =
    i + sub_length <= text_length
    && (String.sub text i sub_length = substring || loop (i + 1))
  in
  loop 0

let test_rss_parser () =
  let feed =
    {|<rss version="2.0"><channel><title>Example</title><link>https://example.test/</link><description>Feed</description><item><title>First article</title><link>https://example.test/article</link><description>Summary</description></item></channel></rss>|}
  in
  match Sparks_rss.Syndications.from_str feed with
  | [article] ->
      check (article.title = "First article") "RSS title should be preserved" ;
      check
        (Uri.to_string article.link = "https://example.test/article")
        "RSS article URL should be preserved" ;
      check (article.description = Some "Summary")
        "RSS description should be preserved"
  | _ ->
      failwith "Expected one parsed RSS article"

let test_image_handling () =
  let module Spark = Sparks_rss.Spark in
  check
    (Spark.normalize_mimetype " Image/JPEG; charset=binary " = "image/jpeg")
    "Image MIME types should ignore parameters and normalize case" ;
  check
    (Spark.image_extension "image/png; charset=binary" = Some ".png")
    "PNG MIME type should be recognized with parameters" ;
  check
    (Spark.image_extension "application/octet-stream" = None)
    "Unsupported MIME types should not be treated as images" ;
  check
    ( Spark.resolve_image_url ~base_url:"https://example.test/news/page.html"
        "../images/cover.jpg"
      = Some "https://example.test/images/cover.jpg" )
    "Relative image URLs should resolve against the article URL" ;
  let soup = Soup.parse "<html><body><img alt='missing source'></body></html>" in
  let remaining =
    Lwt_main.run (Spark.download_and_swap_images (Spark.select_images soup))
  in
  check (remaining = []) "An image without a source should be skipped" ;
  check
    (not (contains (Soup.to_string soup) "<img"))
    "An image without a source should be removed from article markup"

let test_article_xhtml () =
  let text =
    Sparks_rss.Spark.extract_article_text
      "<html><body><article><h1>Title</h1><p>Readable text</p><script>ignore me</script></article></body></html>"
  in
  check (text = "Title Readable text") "Article text should omit script content" ;
  let xhtml =
    Sparks_rss.Spark.make_article_xhtml ~title:"A & B" ~summary:"Summary"
      ~text:"Body" ~images:[]
  in
  check (String.length xhtml > 0 && xhtml.[0] = '<')
    "Article output should be a complete serialized HTML document" ;
  check
    (contains xhtml "A &amp; B")
    "Article titles should be escaped in XHTML" ;
  ignore
    (Xmlm.input_doc_tree ~el:(fun _ _ -> ()) ~data:(fun _ -> ())
       (Xmlm.make_input (`String (0, xhtml))) )

let test_bounded_parallelism () =
  let active = ref 0 and maximum = ref 0 in
  let results =
    Lwt_main.run
      (Sparks_rss.Bounded.map_p ~max_concurrent:2
         (fun value ->
           incr active ;
           maximum := max !maximum !active ;
           let open Lwt.Syntax in
           let* () = Lwt_unix.sleep 0.001 in
           decr active ;
           Lwt.return (value * 2) )
         [0; 1; 2; 3; 4] )
  in
  check (results = [0; 2; 4; 6; 8]) "Bounded mapping should preserve order" ;
  check (!maximum = 2) "Bounded mapping should respect its concurrency limit"

let test_epub_archive () =
  let path = Filename.temp_file "sparks-rss-test-" ".epub" in
  Fun.protect
    ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
    (fun () ->
      Sparks_rss.Epub3.open_out_pub
        ~unique_id:(Sparks_rss.Epub3.Uuid (Sparks_rss.Uuid.uuid4 ()))
        ~title:"Test book" ~ln:"en" ~opt_meta:[] path
      |> fun pub ->
      Sparks_rss.Epub3.save_xhtml_doc pub "Article"
        (Sparks_rss.Spark.make_article_xhtml ~title:"Article" ~summary:""
           ~text:"Hello" ~images:[] )
      |> Sparks_rss.Epub3.close_pub ;
      let archive = Zip.open_in path in
      Fun.protect
        ~finally:(fun () -> Zip.close_in archive)
        (fun () ->
          match Zip.entries archive with
          | [] ->
              failwith "EPUB archive should contain entries"
          | first :: _ ->
              check (first.filename = "mimetype")
                "EPUB mimetype must be the first ZIP entry" ;
              check (first.methd = Zip.Stored)
                "EPUB mimetype must be stored without compression" ;
              check
                (Zip.read_entry archive first = "application/epub+zip")
                "EPUB mimetype entry should contain the standard media type" ;
              let opf =
                Zip.read_entry archive (Zip.find_entry archive "content.opf")
              in
              check
                (contains opf "properties=\"nav\"")
                "The navigation document must be identified in the OPF manifest" ;
              List.iter
                (fun name ->
                  ignore (Zip.find_entry archive name) )
                [ "META-INF/container.xml"; "content.opf"; "nav.xhtml"; "toc.ncx" ] ) )

let () =
  test_rss_parser () ;
  test_image_handling () ;
  test_article_xhtml () ;
  test_bounded_parallelism () ;
  test_epub_archive ()
