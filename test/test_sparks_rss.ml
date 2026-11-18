let check condition message = if not condition then failwith message

let contains text substring =
  let text_length = String.length text
  and sub_length = String.length substring in
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
      check
        (article.description = Some "Summary")
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
  let soup =
    Soup.parse "<html><body><img alt='missing source'></body></html>"
  in
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
      "<html><body><article><h1>Title</h1><p>Readable text</p><script>ignore \
       me</script></article></body></html>"
  in
  check (text = "Title Readable text") "Article text should omit script content" ;
  check
    (Sparks_rss.Spark.normalize_text "valid\016text" = "validtext")
    "Article text should discard XML-invalid control characters" ;
  let xhtml =
    Sparks_rss.Spark.make_article_xhtml ~title:"A & B" ~summary:"Summary"
      ~text:"Body" ~images:[]
  in
  check
    (String.length xhtml > 0 && xhtml.[0] = '<')
    "Article output should be a complete serialized HTML document" ;
  check (contains xhtml "A &amp; B") "Article titles should be escaped in XHTML" ;
  ignore
    (Xmlm.input_doc_tree
       ~el:(fun _ _ -> ())
       ~data:(fun _ -> ())
       (Xmlm.make_input (`String (0, xhtml))) )

let test_hackernews_item_urls () =
  let check_item expected url =
    check
      (Sparks_rss.Hackernews.is_item_url (Uri.of_string url) = expected)
      (Printf.sprintf "Hacker News item detection failed for %s" url)
  in
  check_item true "https://news.ycombinator.com/item?id=41234567" ;
  check_item true "http://news.ycombinator.com/item?id=1" ;
  check_item true "https://news.ycombinator.com/item?id=41234567&p=2" ;
  check_item false "https://news.ycombinator.com/item/" ;
  check_item false "https://news.ycombinator.com/" ;
  check_item false "https://news.ycombinator.com/user?id=who" ;
  check_item false "https://news.ycombinator.com/item" ;
  check_item false "https://news.ycombinator.com/item?id=abc" ;
  check_item false "https://example.com/item?id=123" ;
  check
    ( Sparks_rss.Hackernews.item_id
        (Uri.of_string "https://news.ycombinator.com/item?id=41234567")
    = Some "41234567" )
    "Hacker News item id should be extracted from item URLs"

let test_soup_sanitization () =
  let html =
    "<html><body><article><table width='100%'><tr><td \
     width='50'>cell</td></tr></table><p><a href='#missing'>broken</a> <a \
     href='#ok'>works</a></p><h2 id='ok'>target</h2></article></body></html>"
  in
  let xhtml, _ =
    Lwt_main.run
      (Sparks_rss.Spark.extract_article ~title:"T" ~summary:""
         ~url:"https://example.test/a" html )
  in
  check
    (not (contains xhtml "width=\"100%\""))
    "Non-integer width values should be dropped" ;
  check (contains xhtml "width=\"50\"") "Integer widths should be kept" ;
  check
    (not (contains xhtml "href=\"#missing\""))
    "Internal links without a target id should be unwrapped" ;
  check (contains xhtml "href=\"#ok\"") "Valid internal links should be kept"

let test_hackernews_comments () =
  let html =
    {|<html><body><table class="comment-tree">
      <tr class="athing comtr" id="1"><td><table border="0"><tr>
      <td class="ind" indent="0"><img src="s.gif" height="1" width="0"></td>
      <td class="default"><div><span class="comhead"><a href="user?id=alice">alice</a>
      <span class="age" title="2026-11-17T16:41:03"><a href="item?id=1">2 hours ago</a></span></span></div>
      <div class="commtext c00"><p>First <a href="item?id=2">link</a> text</p></div></td></tr></table></td></tr>
      <tr class="athing comtr" id="2"><td><table border="0"><tr>
      <td class="ind" indent="1"><img src="s.gif" height="1" width="40"></td>
      <td class="default"><div><span class="comhead"><a href="user?id=bob">bob</a>
      <span class="age"><a href="item?id=2">1 day ago</a></span></span></div>
      <div class="commtext c00">Second text</div></td></tr></table></td></tr>
      <tr class="athing comtr" id="3"><td><table border="0"><tr>
      <td class="default"><span class="comhead">[deleted]</span></td></tr></table></td></tr>
      </table></body></html>|}
  in
  match Sparks_rss.Hackernews.parse_comments html with
  | [first; second] ->
      check (first.author = "alice") "HN comment author should be extracted" ;
      check (first.age = "2 hours ago") "HN comment age should be extracted" ;
      check
        (contains first.text "First <a href=\"item?id=2\">link</a> text")
        "HN comment body HTML should be preserved" ;
      check (second.author = "bob") "HN comments should keep document order" ;
      check
        (contains second.text "Second text")
        "HN comment body should be extracted"
  | _ ->
      failwith "Expected two parsed Hacker News comments"

let test_lobsters_comment_author () =
  let html =
    {|<ol class="comments"><li class="comments_subtree"><div id="c_parent" class="comment"><div class="details"><div class="byline"><a href="/~alice" aria-hidden="true"><img src="/avatar.png" alt=""></a><a href="/~alice">alice</a><time>yesterday</time></div><div class="comment_text"><p>Parent comment</p></div></div></div><ol class="comments"><li class="comments_subtree"><div id="c_reply" class="comment"><div class="details"><div class="byline"><a href="/~bob" aria-hidden="true"><img src="/avatar.png" alt=""></a><a href="/~bob">bob</a><time>today</time></div><div class="comment_text"><p>Reply</p></div></div></div></li></ol></li></ol>|}
  in
  match Sparks_rss.Lobsters.parse_comments html with
  | [parent; reply] ->
      check (parent.author = "alice")
        "Lobsters author should use username link text" ;
      check
        (reply.author = "bob" && reply.reply_to = Some "alice")
        "Lobsters replies should parse their author and direct parent"
  | _ ->
      failwith "Expected parent and reply Lobsters comments"

let test_comments_xhtml () =
  let comments =
    [ { Sparks_rss.Comments.author= "a & b"
      ; reply_to= None
      ; age= "3 hours ago"
      ; text= {|<p>Hi &amp; <a href="item?id=2">bye</a> &amp; bye</p>|} }
    ; { Sparks_rss.Comments.author= "carol"
      ; reply_to= None
      ; age= ""
      ; text= "<p>Reply</p>" } ]
  in
  let xhtml = Sparks_rss.Spark.make_comments_xhtml ~title:"A & B" comments in
  check (contains xhtml "Comments:") "Nope, comments should render" ;
  check (contains xhtml "a &amp; b") "Comment authors should be escaped" ;
  check (contains xhtml " · 3 hours ago") "Comment age should render" ;
  check (contains xhtml "<hr") "Comments should be separated by rules" ;
  check (not (contains xhtml "hr></hr")) "Separators should be void elements" ;
  ignore
    (Xmlm.input_doc_tree
       ~el:(fun _ _ -> ())
       ~data:(fun _ -> ())
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

let read_u16 data offset =
  Char.code (Bytes.get data offset)
  lor (Char.code (Bytes.get data (offset + 1)) lsl 8)

let read_member archive path =
  match Zipc.find path archive with
  | Some member ->
      member
  | None ->
      failwith ("EPUB archive is missing member: " ^ path)

let member_data archive path =
  let member = read_member archive path in
  match Zipc.Member.kind member with
  | Zipc.Member.File file -> (
    match Zipc.File.to_binary_string file with
    | Ok data ->
        data
    | Error msg ->
        failwith ("Unable to read EPUB member " ^ path ^ ": " ^ msg) )
  | Zipc.Member.Dir ->
      failwith ("EPUB member is not a file: " ^ path)

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
      |> fun pub ->
      Sparks_rss.Epub3.save_support_doc pub "images/test.png" `Png "png data"
      |> Sparks_rss.Epub3.close_pub ;
      let channel = open_in_bin path in
      let data =
        Bytes.of_string
          (really_input_string channel (in_channel_length channel))
      in
      close_in channel ;
      (* The first local file header must be the stored mimetype entry
         without a ZIP extra field, as required by the EPUB OCF container. *)
      check
        (Bytes.sub_string data 0 4 = "PK\x03\x04")
        "EPUB must start with a ZIP local file header" ;
      check (read_u16 data 8 = 0) "EPUB mimetype entry must be stored" ;
      let name_length = read_u16 data 26 and extra_length = read_u16 data 28 in
      check
        (Bytes.sub_string data 30 name_length = "mimetype")
        "EPUB mimetype must be the first ZIP entry" ;
      check (extra_length = 0)
        "EPUB mimetype entry must not carry a ZIP extra field" ;
      check
        (Bytes.sub_string data (30 + name_length) 20 = "application/epub+zip")
        "EPUB mimetype entry should contain the standard media type" ;
      let archive =
        match Zipc.of_binary_string (Bytes.to_string data) with
        | Ok archive ->
            archive
        | Error msg ->
            failwith ("EPUB archive is not a valid ZIP: " ^ msg)
      in
      check
        ( match Zipc.Member.kind (read_member archive "mimetype") with
        | Zipc.Member.File file ->
            Zipc.File.compression file = Zipc.Stored
        | Zipc.Member.Dir ->
            false )
        "EPUB mimetype member must be stored" ;
      let opf = member_data archive "content.opf" in
      check
        (contains opf "properties=\"nav\"")
        "The navigation document must be identified in the OPF manifest" ;
      check
        (contains opf "images/test.png" && contains opf "image/png")
        "PNG manifest items must be declared as image/png" ;
      List.iter
        (fun name -> ignore (member_data archive name))
        ["META-INF/container.xml"; "content.opf"; "nav.xhtml"; "toc.ncx"] )

let () =
  test_rss_parser () ;
  test_hackernews_item_urls () ;
  test_hackernews_comments () ;
  test_lobsters_comment_author () ;
  test_image_handling () ;
  test_article_xhtml () ;
  test_soup_sanitization () ;
  test_comments_xhtml () ;
  test_bounded_parallelism () ;
  test_epub_archive ()
