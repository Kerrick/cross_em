# frozen_string_literal: true

module CrossEm
  module Presentation
    # A plain-text license, as written, broken back into what its author
    # meant: paragraphs, hard-wrapped near 72 columns, become one line each
    # so a sheet can wrap them to its own width; short lines (an address,
    # a list, a signature) stay as they are; indentation and "> " quoting
    # carry over; a line of dashes becomes a rule. No word of the text is
    # changed or left out.
    module Reflow
      # A run of text, +indent+ columns in, with +quote+ ("> " or "")
      # before it.
      Text = Data.define(:indent, :quote, :text)
      Gap = Data.define
      Rule = Data.define

      # A line at least this long was wrapped by its author, not ended.
      WRAPPED = 50

      module_function

      def parse(text)
        pieces = []
        previous = nil
        text.each_line(chomp: true) do |line|
          if line.strip.empty?
            pieces << Gap.new unless pieces.last.is_a?(Gap) || pieces.empty?
            previous = nil
          elsif line.strip.match?(/\A[-=*_]{8,}\z/)
            pieces << Rule.new
            previous = nil
          else
            indent = line[/\A */].size
            quote = line[indent..][/\A> ?/] || ""
            body = line[(indent + quote.size)..].rstrip
            if previous && continues?(previous, indent, quote)
              last = pieces.last
              pieces[-1] = last.with(text: "#{last.text} #{body}")
            else
              pieces << Text.new(indent:, quote: quote.rstrip.empty? ? "" : "> ", text: body)
            end
            previous = [indent, quote, line.rstrip.length]
          end
        end
        pieces.pop while pieces.last.is_a?(Gap)
        pieces
      end

      def continues?(previous, indent, quote)
        before_indent, before_quote, before_length = previous
        before_indent == indent && before_quote == quote && before_length >= WRAPPED
      end
    end
  end
end
