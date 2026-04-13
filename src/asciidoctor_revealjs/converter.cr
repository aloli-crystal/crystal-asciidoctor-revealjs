require "crystal-asciidoctor"
require "html"

module AsciidoctorRevealjs
  # Converts an AsciiDoc document to a reveal.js HTML presentation.
  #
  # Registered for the "revealjs" backend so that:
  #   Asciidoctor.load(source, {"backend" => "revealjs"})
  # automatically selects this converter.
  class Converter < Asciidoctor::Converter::Base
    register_for "revealjs"

    # ------------------------------------------------------------------ #
    # Constants
    # ------------------------------------------------------------------ #

    DEFAULT_REVEALJS_DIR      = "https://cdn.jsdelivr.net/npm/reveal.js@5.1.0"
    DEFAULT_THEME             = "black"
    DEFAULT_TRANSITION        = "slide"
    DEFAULT_HIGHLIGHTJS_THEME = "monokai"

    # ------------------------------------------------------------------ #
    # Constructor
    # ------------------------------------------------------------------ #

    def initialize(backend : String = "revealjs")
      super(backend)
      init_backend_traits(
        basebackend: "html",
        filetype: "html",
        htmlsyntax: "html",
        outfilesuffix: ".html"
      )
    end

    # ------------------------------------------------------------------ #
    # Main entry point
    # ------------------------------------------------------------------ #

    def convert(node : Asciidoctor::AbstractNode, transform : String? = nil) : String
      transform ||= node.node_name
      dispatch(node, transform)
    end

    def dispatch(node : Asciidoctor::AbstractNode, transform : String) : String
      case transform
      when "document"         then convert_document(node)
      when "embedded"         then convert_embedded(node)
      when "section"          then convert_section(node)
      when "admonition"       then convert_admonition(node)
      when "audio"            then ""
      when "colist"           then convert_colist(node)
      when "dlist"            then convert_dlist(node)
      when "example"          then convert_block_generic(node, "exampleblock")
      when "floating_title"   then convert_floating_title(node)
      when "image"            then convert_image(node)
      when "inline_anchor"    then convert_inline_anchor(node)
      when "inline_break"     then convert_inline_break(node)
      when "inline_button"    then convert_inline_button(node)
      when "inline_callout"   then convert_inline_callout(node)
      when "inline_footnote"  then convert_inline_footnote(node)
      when "inline_image"     then convert_inline_image(node)
      when "inline_indexterm" then ""
      when "inline_kbd"       then convert_inline_kbd(node)
      when "inline_menu"      then convert_inline_menu(node)
      when "inline_quoted"    then convert_inline_quoted(node)
      when "listing"          then convert_listing(node)
      when "literal"          then convert_literal(node)
      when "olist"            then convert_olist(node)
      when "open"             then convert_open(node)
      when "page_break"       then ""
      when "paragraph"        then convert_paragraph(node)
      when "pass"             then content_only(node)
      when "preamble"         then convert_preamble(node)
      when "quote"            then convert_quote(node)
      when "sidebar"          then convert_sidebar(node)
      when "stem"             then convert_stem(node)
      when "table"            then convert_table(node)
      when "thematic_break"   then "<hr>"
      when "toc"              then ""
      when "ulist"            then convert_ulist(node)
      when "verse"            then convert_verse(node)
      when "video"            then convert_video(node)
      else                         ""
      end
    end

    # ------------------------------------------------------------------ #
    # Document
    # ------------------------------------------------------------------ #

    private def convert_document(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Document)
      doc = node

      revealjs_dir = s_attr(doc, "revealjsdir", DEFAULT_REVEALJS_DIR)
      theme = s_attr(doc, "revealjs_theme", DEFAULT_THEME)
      custom_theme = doc.attr("revealjs_customtheme")
      transition = s_attr(doc, "revealjs_transition", DEFAULT_TRANSITION)
      width = doc.attr("revealjs_width")
      height = doc.attr("revealjs_height")
      controls = s_attr(doc, "revealjs_controls", "true")
      progress = s_attr(doc, "revealjs_progress", "true")
      history = s_attr(doc, "revealjs_history", "false")
      slide_number = s_attr(doc, "revealjs_slidenumber", "false")
      center = s_attr(doc, "revealjs_center", "true")
      hl_theme = s_attr(doc, "highlightjs-theme", DEFAULT_HIGHLIGHTJS_THEME)

      title = doc.doctitle || "Untitled Presentation"

      theme_css = if ct = custom_theme
                    %(<link rel="stylesheet" href="#{esc(ct)}">)
                  else
                    %(<link rel="stylesheet" href="#{revealjs_dir}/dist/theme/#{esc(theme)}.css" id="theme">)
                  end

      slides_content = convert_embedded(node)

      String.build do |io|
        io << "<!DOCTYPE html>\n"
        io << %(<html lang="#{s_attr(doc, "lang", "en")}">\n)
        io << "<head>\n"
        io << %(<meta charset="utf-8">\n)
        io << %(<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">\n)
        io << "<title>" << esc(title) << "</title>\n"
        if (desc = doc.attr("description"))
          io << %(<meta name="description" content="#{esc(desc)}">\n)
        end
        if (author = doc.attr("author"))
          io << %(<meta name="author" content="#{esc(author)}">\n)
        end
        io << %(<link rel="stylesheet" href="#{revealjs_dir}/dist/reset.css">\n)
        io << %(<link rel="stylesheet" href="#{revealjs_dir}/dist/reveal.css">\n)
        io << theme_css << "\n"
        io << %(<link rel="stylesheet" href="#{revealjs_dir}/plugin/highlight/#{esc(hl_theme)}.css">\n)
        di = doc.docinfo(:head)
        io << di << "\n" unless di.empty?
        io << "</head>\n"
        io << "<body>\n"
        io << %(<div class="reveal">\n)
        io << %(<div class="slides">\n)
        io << slides_content
        io << "</div>\n"
        io << "</div>\n"
        io << %(<script src="#{revealjs_dir}/dist/reveal.js"></script>\n)
        io << %(<script src="#{revealjs_dir}/plugin/notes/notes.js"></script>\n)
        io << %(<script src="#{revealjs_dir}/plugin/highlight/highlight.js"></script>\n)
        io << "<script>\n"
        io << "Reveal.initialize({\n"
        io << "  controls: " << controls << ",\n"
        io << "  progress: " << progress << ",\n"
        io << "  history: " << history << ",\n"
        io << "  center: " << center << ",\n"
        io << "  slideNumber: " << slide_number << ",\n"
        io << "  transition: '" << esc(transition) << "',\n"
        if w = width
          io << "  width: " << fmt_dim(w) << ",\n"
        end
        if h = height
          io << "  height: " << fmt_dim(h) << ",\n"
        end
        io << "  plugins: [RevealNotes, RevealHighlight]\n"
        io << "});\n"
        io << "</script>\n"
        df = doc.docinfo(:footer)
        io << df << "\n" unless df.empty?
        io << "</body>\n"
        io << "</html>\n"
      end
    end

    # ------------------------------------------------------------------ #
    # Embedded (slides content only, no HTML wrapper)
    # ------------------------------------------------------------------ #

    private def convert_embedded(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Document)
      doc = node

      String.build do |io|
        # Title slide
        title = doc.doctitle
        if title && !doc.notitle
          io << %(<section class="title-slide">\n)
          io << "<h1>" << title << "</h1>\n"
          if (author = doc.attr("author"))
            io << %(<p class="author">) << esc(author) << "</p>\n"
          end
          if (revdate = doc.attr("revdate"))
            io << %(<p class="date">) << esc(revdate) << "</p>\n"
          end
          io << "</section>\n"
        end

        # Preamble (content before first section)
        preamble_blocks = doc.blocks.take_while { |b| !b.is_a?(Asciidoctor::Section) }
        if preamble_blocks.size > 0
          io << "<section>\n"
          preamble_blocks.each { |b| io << b.convert << "\n" }
          io << "</section>\n"
        end

        # Sections
        doc.blocks.each do |block|
          next unless block.is_a?(Asciidoctor::Section)
          io << convert_section_node(block)
        end
      end
    end

    # ------------------------------------------------------------------ #
    # Section -> <section> slides
    # ------------------------------------------------------------------ #

    private def convert_section(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Section)
      convert_section_node(node)
    end

    private def convert_section_node(section : Asciidoctor::Section) : String
      level = section.level
      has_subsections = section.blocks.any? { |b| b.is_a?(Asciidoctor::Section) }
      section_attrs = build_section_attrs(section)

      String.build do |io|
        if level == 1 && has_subsections
          # Horizontal slide group with vertical sub-slides
          io << "<section>\n"

          # The level-1 section itself is the first vertical slide
          io << "<section" << section_attrs << ">\n"
          append_slide_title(io, section)
          append_non_section_blocks(io, section)
          io << "</section>\n"

          section.blocks.each do |block|
            next unless block.is_a?(Asciidoctor::Section)
            io << convert_section_node(block)
          end

          io << "</section>\n"
        else
          io << "<section" << section_attrs << ">\n"
          append_slide_title(io, section)
          append_non_section_blocks(io, section)

          section.blocks.each do |block|
            next unless block.is_a?(Asciidoctor::Section)
            io << convert_section_node(block)
          end

          io << "</section>\n"
        end
      end
    end

    private def build_section_attrs(section : Asciidoctor::Section) : String
      parts = [] of String

      if (id = section.id)
        parts << %( id="#{esc(id)}")
      end

      {% for pair in [{"background-image", "data-background-image"},
                      {"background-color", "data-background-color"},
                      {"background-size", "data-background-size"},
                      {"background-position", "data-background-position"},
                      {"background-repeat", "data-background-repeat"},
                      {"background-transition", "data-background-transition"},
                      {"background-video", "data-background-video"},
                      {"transition", "data-transition"},
                      {"transition-speed", "data-transition-speed"},
                      {"state", "data-state"}] %}
        if (val = section.attr({{ pair[0] }}))
          parts << %( {{ pair[1].id }}="#{esc(val)}")
        end
      {% end %}

      if section.option?("auto-animate")
        parts << " data-auto-animate"
      end

      parts.join
    end

    private def append_slide_title(io : IO, section : Asciidoctor::Section) : Nil
      return if section.option?("notitle")
      if (title = section.title)
        h = {section.level, 6}.min
        io << "<h" << h << ">" << title << "</h" << h << ">\n"
      end
    end

    private def append_non_section_blocks(io : IO, section : Asciidoctor::Section) : Nil
      section.blocks.each do |block|
        next if block.is_a?(Asciidoctor::Section)
        io << block.convert << "\n"
      end
    end

    # ------------------------------------------------------------------ #
    # Paragraph
    # ------------------------------------------------------------------ #

    private def convert_paragraph(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::AbstractBlock)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      role = node.role
      cls = role ? %( class="#{esc(role)}") : ""
      content = block.is_a?(Asciidoctor::Block) ? (block.content || "") : ""
      "<p#{id_a}#{cls}#{frag}>#{content}</p>"
    end

    # ------------------------------------------------------------------ #
    # Lists
    # ------------------------------------------------------------------ #

    private def convert_ulist(node : Asciidoctor::AbstractNode) : String
      convert_list_node(node, "ul")
    end

    private def convert_olist(node : Asciidoctor::AbstractNode) : String
      convert_list_node(node, "ol")
    end

    private def convert_list_node(node : Asciidoctor::AbstractNode, tag : String) : String
      return "" unless node.is_a?(Asciidoctor::List)
      list = node
      id_a = id_attr(node)
      role = node.role
      cls = role ? %( class="#{esc(role)}") : ""
      frag = fragment_attr(node)

      String.build do |io|
        io << "<" << tag << id_a << cls << frag << ">\n"
        list.items.each do |item|
          next unless item.is_a?(Asciidoctor::ListItem)
          ifrag = fragment_attr(item)
          text = item.text || ""
          io << "<li" << ifrag << ">" << text
          if item.blocks.size > 0
            io << "\n"
            item.blocks.each { |b| io << b.convert << "\n" }
          end
          io << "</li>\n"
        end
        io << "</" << tag << ">"
      end
    end

    private def convert_dlist(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::List)
      list = node
      id_a = id_attr(node)
      frag = fragment_attr(node)

      String.build do |io|
        io << "<dl" << id_a << frag << ">\n"
        list.items.each do |item|
          next unless item.is_a?(Asciidoctor::ListItem)
          io << "<dt>" << (item.text || "") << "</dt>\n"
          item.blocks.each { |b| io << "<dd>" << b.convert << "</dd>\n" }
        end
        io << "</dl>"
      end
    end

    private def convert_colist(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::List)
      list = node
      id_a = id_attr(node)

      String.build do |io|
        io << %(<ol#{id_a} class="colist">\n)
        list.items.each do |item|
          next unless item.is_a?(Asciidoctor::ListItem)
          io << "<li>" << (item.text || "") << "</li>\n"
        end
        io << "</ol>"
      end
    end

    # ------------------------------------------------------------------ #
    # Table
    # ------------------------------------------------------------------ #

    private def convert_table(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Table)
      table = node
      id_a = id_attr(node)
      role = node.role
      classes = "tableblock"
      classes = "#{classes} #{role}" if role
      frag = fragment_attr(node)

      String.build do |io|
        has_title = !!table.title
        if (t = table.title)
          io << %(<div class="table-wrapper"#{frag}>\n)
          io << %(<div class="title">) << esc(t) << "</div>\n"
        end

        io << %(<table#{id_a} class="#{classes}">\n)

        render_table_section(io, table.rows.head, "thead", "th")
        render_table_section(io, table.rows.body, "tbody", "td")
        render_table_section(io, table.rows.foot, "tfoot", "td")

        io << "</table>\n"
        io << "</div>" if has_title
      end
    end

    private def render_table_section(io : IO, rows : Array(Array(Asciidoctor::Table::Cell)), tag : String, cell_tag : String) : Nil
      return if rows.empty?
      io << "<" << tag << ">\n"
      rows.each do |row|
        io << "<tr>\n"
        row.each { |cell| io << "<" << cell_tag << ">" << cell.text << "</" << cell_tag << ">\n" }
        io << "</tr>\n"
      end
      io << "</" << tag << ">\n"
    end

    # ------------------------------------------------------------------ #
    # Code blocks (listing, literal)
    # ------------------------------------------------------------------ #

    private def convert_listing(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      source = block.content || block.source
      lang = block.attr("language")

      if lang
        %(<pre#{id_a}#{frag}><code class="language-#{esc(lang)}" data-trim data-noescape>#{source}</code></pre>)
      else
        %(<pre#{id_a}#{frag}><code data-trim data-noescape>#{source}</code></pre>)
      end
    end

    private def convert_literal(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      source = block.content || block.source
      "<pre#{id_a}#{frag}>#{source}</pre>"
    end

    # ------------------------------------------------------------------ #
    # Admonition -> speaker notes or styled block
    # ------------------------------------------------------------------ #

    private def convert_admonition(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      style = (block.attr("style") || block.attr("name") || "note").to_s.downcase
      role = block.role

      if style == "note" && role && role.includes?("speaker")
        content = block.content || ""
        return %(<aside class="notes">\n#{content}\n</aside>)
      end

      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || ""
      label = block.attr("textlabel") || style.upcase
      %(<div#{id_a} class="admonitionblock #{esc(style)}"#{frag}>\n<strong>#{esc(label)}</strong>\n#{content}\n</div>)
    end

    # ------------------------------------------------------------------ #
    # Image
    # ------------------------------------------------------------------ #

    private def convert_image(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      target = block.attr("target") || ""
      alt = block.attr("alt") || ""
      id_a = id_attr(node)
      frag = fragment_attr(node)

      w_attr = if (w = block.attr("width"))
                 %( width="#{esc(w)}")
               else
                 ""
               end
      h_attr = if (h = block.attr("height"))
                 %( height="#{esc(h)}")
               else
                 ""
               end

      image_uri = block.image_uri(target)

      String.build do |io|
        io << %(<div#{id_a} class="imageblock"#{frag}>\n)
        io << %(<img src="#{esc(image_uri)}" alt="#{esc(alt)}"#{w_attr}#{h_attr}>\n)
        if (t = block.title)
          io << %(<div class="title">) << esc(t) << "</div>\n"
        end
        io << "</div>"
      end
    end

    # ------------------------------------------------------------------ #
    # Quote & Verse
    # ------------------------------------------------------------------ #

    private def convert_quote(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || ""
      attribution = block.attr("attribution")
      citetitle = block.attr("citetitle")

      String.build do |io|
        io << "<blockquote" << id_a << frag << ">\n"
        io << content << "\n"
        if attribution || citetitle
          io << "<footer>"
          if a = attribution
            io << "&mdash; " << esc(a)
          end
          if ct = citetitle
            io << ", <cite>" << esc(ct) << "</cite>"
          end
          io << "</footer>\n"
        end
        io << "</blockquote>"
      end
    end

    private def convert_verse(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || block.source
      %(<pre#{id_a} class="verse"#{frag}>#{content}</pre>)
    end

    # ------------------------------------------------------------------ #
    # Example, Sidebar, Open, Preamble, Stem
    # ------------------------------------------------------------------ #

    private def convert_block_generic(node : Asciidoctor::AbstractNode, css_class : String) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || ""

      String.build do |io|
        io << %(<div#{id_a} class="#{css_class}"#{frag}>\n)
        if (t = block.title)
          io << %(<div class="title">) << esc(t) << "</div>\n"
        end
        io << %(<div class="content">\n) << content << "\n</div>\n"
        io << "</div>"
      end
    end

    private def convert_sidebar(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || ""

      String.build do |io|
        io << %(<aside#{id_a} class="sidebar"#{frag}>\n)
        if (t = block.title)
          io << %(<div class="title">) << esc(t) << "</div>\n"
        end
        io << content << "\n"
        io << "</aside>"
      end
    end

    private def convert_open(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      role = block.role

      # [.notes] open block -> speaker notes
      if role && role.includes?("notes")
        content = block.content || ""
        return %(<aside class="notes">\n#{content}\n</aside>)
      end

      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || ""
      cls = role ? %( class="#{esc(role)}") : ""
      "<div#{id_a}#{cls}#{frag}>\n#{content}\n</div>"
    end

    private def convert_preamble(node : Asciidoctor::AbstractNode) : String
      if node.is_a?(Asciidoctor::Block)
        (node.content || "").to_s
      elsif node.is_a?(Asciidoctor::AbstractBlock)
        (node.content || "").to_s
      else
        ""
      end
    end

    private def convert_stem(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      id_a = id_attr(node)
      frag = fragment_attr(node)
      content = block.content || block.source
      %(<div#{id_a} class="stemblock"#{frag}>\n#{content}\n</div>)
    end

    private def convert_floating_title(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::AbstractBlock)
      level = node.level
      h = {level, 6}.min
      id_a = id_attr(node)
      title = node.title || ""
      %(<h#{h}#{id_a} class="float">#{title}</h#{h}>)
    end

    # ------------------------------------------------------------------ #
    # Inline elements
    # ------------------------------------------------------------------ #

    private def convert_inline_anchor(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      inline = node
      case inline.type
      when :xref
        text = inline.text || inline.target || ""
        target = inline.target || ""
        %(<a href="#{esc(target)}">#{text}</a>)
      when :link
        text = inline.text || inline.target || ""
        target = inline.target || ""
        %(<a href="#{esc(target)}">#{text}</a>)
      when :ref
        id = inline.id || ""
        %(<a id="#{esc(id)}"></a>)
      when :bibref
        id = inline.id || ""
        text = inline.text || "[#{id}]"
        %(<a id="#{esc(id)}"></a>[#{text}])
      else
        text = inline.text || ""
        target = inline.target || ""
        %(<a href="#{esc(target)}">#{text}</a>)
      end
    end

    private def convert_inline_break(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      "#{node.text || ""}<br>"
    end

    private def convert_inline_button(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      %(<b class="button">#{node.text || ""}</b>)
    end

    private def convert_inline_callout(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      %(<i class="conum" data-value="#{esc(node.text || "")}"></i>)
    end

    private def convert_inline_footnote(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      %(<sup class="footnote">[#{node.text || ""}]</sup>)
    end

    private def convert_inline_image(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      target = node.target || ""
      alt = node.attr("alt") || ""
      %(<span class="image"><img src="#{esc(target)}" alt="#{esc(alt)}"></span>)
    end

    private def convert_inline_kbd(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      "<kbd>#{node.text || ""}</kbd>"
    end

    private def convert_inline_menu(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      %(<span class="menuseq">#{node.text || ""}</span>)
    end

    private def convert_inline_quoted(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Inline)
      inline = node
      text = inline.text || ""
      case inline.type
      when :emphasis    then "<em>#{text}</em>"
      when :strong      then "<strong>#{text}</strong>"
      when :monospaced  then "<code>#{text}</code>"
      when :superscript then "<sup>#{text}</sup>"
      when :subscript   then "<sub>#{text}</sub>"
      when :double      then "&#8220;#{text}&#8221;"
      when :single      then "&#8216;#{text}&#8217;"
      when :mark        then "<mark>#{text}</mark>"
      when :asciimath   then "\\$#{text}\\$"
      when :latexmath   then "\\(#{text}\\)"
      when :unquoted
        if (role = inline.role)
          %(<span class="#{esc(role)}">#{text}</span>)
        else
          text
        end
      else
        text
      end
    end

    private def convert_video(node : Asciidoctor::AbstractNode) : String
      return "" unless node.is_a?(Asciidoctor::Block)
      block = node
      target = block.attr("target") || ""
      id_a = id_attr(node)
      frag = fragment_attr(node)

      String.build do |io|
        io << %(<div#{id_a} class="videoblock"#{frag}>\n)
        io << %(<video src="#{esc(target)}")
        if p = block.attr("poster")
          io << %( poster="#{esc(p)}")
        end
        if w = block.attr("width")
          io << %( width="#{esc(w)}")
        end
        if h = block.attr("height")
          io << %( height="#{esc(h)}")
        end
        io << " controls" if block.option?("controls") || !block.option?("nocontrols")
        io << " autoplay" if block.option?("autoplay")
        io << " loop" if block.option?("loop")
        io << ">\nYour browser does not support the video tag.\n</video>\n"
        if (t = block.title)
          io << %(<div class="title">) << esc(t) << "</div>\n"
        end
        io << "</div>"
      end
    end

    # ------------------------------------------------------------------ #
    # Helpers
    # ------------------------------------------------------------------ #

    private def fragment_attr(node : Asciidoctor::AbstractNode) : String
      if node.is_a?(Asciidoctor::AbstractBlock)
        if node.option?("step") || (node.role && node.role.not_nil!.includes?("fragment"))
          return %( class="fragment")
        end
      end
      ""
    end

    private def id_attr(node : Asciidoctor::AbstractNode) : String
      if (id = node.id)
        %( id="#{esc(id)}")
      else
        ""
      end
    end

    # Shortcut: doc.attr with guaranteed non-nil return.
    private def s_attr(doc : Asciidoctor::Document, name : String, default : String) : String
      doc.attr(name, default) || default
    end

    private def fmt_dim(value : String) : String
      value.to_i? ? value : "'#{HTML.escape(value)}'"
    end

    private def esc(text : String) : String
      HTML.escape(text)
    end
  end
end
