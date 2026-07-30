require "./spec_helper"

# Helper to load and convert an AsciiDoc source string using the revealjs converter.
private def convert(source : String, standalone : Bool = true) : String
  doc = Asciicrystal.load(source, {"safe" => "safe"})
  # Replace the default HTML5 converter with our revealjs converter
  converter = AsciicrystalRevealjs::Converter.new
  doc.converter = converter
  if standalone
    doc.options["standalone"] = true
    converter.convert(doc, "document")
  else
    converter.convert(doc, "embedded")
  end
end

# Helper for embedded-only output (no HTML wrapper).
private def convert_embedded(source : String) : String
  convert(source, standalone: false)
end

describe AsciicrystalRevealjs::Converter do
  describe "standalone document" do
    it "generates a complete HTML document with reveal.js scripts" do
      input = <<-ADOC
      = My Presentation
      Author Name

      == Slide 1

      Hello World

      == Slide 2

      Goodbye World
      ADOC

      html = convert(input)
      html.should contain("<!DOCTYPE html>")
      html.should contain("<html")
      html.should contain("reveal.js")
      html.should contain("Reveal.initialize")
      html.should contain(%(<div class="reveal">))
      html.should contain(%(<div class="slides">))
      html.should contain("</html>")
    end

    it "includes the document title in <title> tag" do
      html = convert("= My Presentation\n\n== Slide 1\n\nContent")
      html.should contain("<title>My Presentation</title>")
    end

    it "loads reveal.js from CDN by default" do
      html = convert("= Test\n\n== Slide\n\nContent")
      html.should contain("cdn.jsdelivr.net/npm/reveal.js@5.1.0")
    end

    it "uses the configured theme" do
      input = <<-ADOC
      = Test
      :revealjs_theme: moon

      == Slide

      Content
      ADOC

      html = convert(input)
      html.should contain("moon.css")
    end

    it "uses a custom theme URL" do
      input = <<-ADOC
      = Test
      :revealjs_customtheme: https://example.com/mytheme.css

      == Slide

      Content
      ADOC

      html = convert(input)
      html.should contain("https://example.com/mytheme.css")
      # Should NOT include a standard theme link
      html.should_not contain("dist/theme/black.css")
    end

    it "respects transition setting" do
      input = <<-ADOC
      = Test
      :revealjs_transition: fade

      == Slide

      Content
      ADOC

      html = convert(input)
      html.should contain("transition: 'fade'")
    end

    it "respects width and height settings" do
      input = <<-ADOC
      = Test
      :revealjs_width: 1920
      :revealjs_height: 1080

      == Slide

      Content
      ADOC

      html = convert(input)
      html.should contain("width: 1920")
      html.should contain("height: 1080")
    end

    it "respects controls and progress settings" do
      input = <<-ADOC
      = Test
      :revealjs_controls: false
      :revealjs_progress: false

      == Slide

      Content
      ADOC

      html = convert(input)
      html.should contain("controls: false")
      html.should contain("progress: false")
    end
  end

  describe "title slide" do
    it "generates a title slide" do
      html = convert_embedded("= My Presentation\n\n== Slide 1\n\nContent")
      html.should contain(%(<section class="title-slide">))
      html.should contain("<h1>My Presentation</h1>")
    end

    it "includes author on title slide" do
      input = <<-ADOC
      = My Presentation
      John Doe

      == Slide

      Content
      ADOC

      html = convert_embedded(input)
      html.should contain("John Doe")
    end
  end

  describe "sections as slides" do
    it "converts level-1 sections to horizontal slides" do
      input = <<-ADOC
      = Presentation

      == Slide A

      Content A

      == Slide B

      Content B
      ADOC

      html = convert_embedded(input)
      html.should contain("<section")
      html.should contain("Slide A")
      html.should contain("Slide B")
    end

    it "converts level-2 sections to vertical slides within a horizontal group" do
      input = <<-ADOC
      = Presentation

      == Horizontal Slide

      Main content

      === Vertical Slide 1

      Sub content 1

      === Vertical Slide 2

      Sub content 2
      ADOC

      html = convert_embedded(input)
      # The outer section wraps the horizontal + verticals
      html.should contain("Vertical Slide 1")
      html.should contain("Vertical Slide 2")
      # There should be nested <section> elements
      html.scan(/<section/).size.should be >= 4 # title + horizontal + 2 vertical
    end
  end

  describe "speaker notes" do
    it "converts [.notes] open block to <aside class='notes'>" do
      input = <<-ADOC
      = Test

      == Slide

      Visible content

      [.notes]
      --
      These are speaker notes
      --
      ADOC

      html = convert_embedded(input)
      html.should contain(%(<aside class="notes">))
    end
  end

  describe "fragments" do
    it "applies fragment class for [%step] option" do
      input = <<-ADOC
      = Test

      == Slide

      [%step]
      Content that appears incrementally
      ADOC

      html = convert_embedded(input)
      html.should contain(%(class="fragment"))
    end
  end

  describe "background attributes" do
    it "converts background-image to data-background-image" do
      input = <<-ADOC
      = Test

      [background-image="sky.jpg"]
      == Slide

      Content
      ADOC

      html = convert_embedded(input)
      html.should contain(%(data-background-image="sky.jpg"))
    end
  end

  describe "standard blocks" do
    it "converts paragraphs" do
      html = convert_embedded("= Test\n\n== Slide\n\nA simple paragraph.")
      html.should contain("<p>")
    end

    it "converts unordered lists" do
      input = <<-ADOC
      = Test

      == Slide

      * Item 1
      * Item 2
      * Item 3
      ADOC

      html = convert_embedded(input)
      html.should contain("<ul")
      html.should contain("<li>")
    end

    it "converts ordered lists" do
      input = <<-ADOC
      = Test

      == Slide

      . First
      . Second
      . Third
      ADOC

      html = convert_embedded(input)
      html.should contain("<ol")
      html.should contain("<li>")
    end

    it "converts source code blocks" do
      input = <<-ADOC
      = Test

      == Slide

      [source,python]
      ----
      print("Hello")
      ----
      ADOC

      html = convert_embedded(input)
      html.should contain("<pre")
      html.should contain("<code")
      html.should contain("language-python")
      html.should contain("data-trim")
    end

    it "converts tables" do
      input = <<-ADOC
      = Test

      == Slide

      |===
      | Header 1 | Header 2

      | Cell 1
      | Cell 2
      |===
      ADOC

      html = convert_embedded(input)
      html.should contain("<table")
    end

    it "converts images" do
      input = <<-ADOC
      = Test

      == Slide

      image::photo.png[A photo]
      ADOC

      html = convert_embedded(input)
      html.should contain("<img")
      html.should contain("photo.png")
    end

    it "converts blockquotes" do
      input = <<-ADOC
      = Test

      == Slide

      [quote, Albert Einstein]
      ____
      Imagination is more important than knowledge.
      ____
      ADOC

      html = convert_embedded(input)
      html.should contain("<blockquote")
      html.should contain("Albert Einstein")
    end

    it "converts inline formatting" do
      input = <<-ADOC
      = Test

      == Slide

      This has *bold* and _italic_ text.
      ADOC

      html = convert_embedded(input)
      html.should contain("<strong>bold</strong>")
      html.should contain("<em>italic</em>")
    end
  end

  describe "version" do
    it "has correct version" do
      AsciicrystalRevealjs::VERSION.should eq("5.2.0.5")
    end
  end
end
