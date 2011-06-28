class Token
end

# Represents a "live" variable, which is expected to be in the data hash
# passed to Parser.
class VariableToken < Token
  attr_accessor :keys

  def initialize(expr)    
    @keys = expr.split(":").collect {|k| k.downcase.to_sym}
  end

  def parse(data={})
    # Recursively apply keys to narrow the scope of the hash to the wanted variable.
    val =@keys.reduce(data) do |scope, key|
        scope = (scope.is_a?(Hash) && scope.has_key?(key)) ? scope[key] : "Unknown"
    end
    val.to_s
  end

  def ==(other)
    return other.keys == self.keys
  end
end

# Represents a snippet of normal text.
class StringToken < Token
  def initialize(str)
    @str = str
  end

  def parse(data={})
    @str
  end

  def ==(other)
    return other.parse == self.parse
  end
end

# A conditional block, which nests other tokens.
class ConditionalToken < Token
  def initialize(str)
    unless m = str.match(/If (.+)/) 
      throw :invalid_conditional
    end
    @cond = VariableToken.new(m[1])     
    @toks = []
  end

  def push(tok)
    @toks.push(tok)
  end

  def parse(data = {})
    if @cond.parse(data) == "true"
      @toks.reduce("") do |output, tok|
        output += tok.parse(data)
      end  
    else
      ""
    end
  end

end

# Breaks a string into a list of Tokens. Note that this is *not* a general-purpose
# lexer.
class Lexer
  def self.lex(str)
    # Read in token after token until the string is consumed.
    toks = []
    stack = [toks]
    pos = 0
    while m = str[pos .. str.length].match(/\[(.+?)\]/) do
      # Push the leading static string unless it's empty.
      stack.last.push(StringToken.new(str[pos ... pos + m.begin(0)])) unless m.begin(0) == 0
      
      # Handle conditionals
      if m[1].start_with?("If ") then
          c = ConditionalToken.new(m[1])
          stack.last.push(c)
          stack.push(c) 
      elsif m[1].start_with?("EndIf") then
          stack.pop
      else
          stack.last.push(VariableToken.new(m[1]))
      end
  
      pos += m.end(0)
    end
    # Make sure to catch any trailing normal text.
    if pos < str.length then
      toks.push(StringToken.new(str[pos .. str.length]))
    end

    return toks
  end

end

# Parses a list of tokens.
class Parser
  def self.parse(toks, data = {})
    toks.reduce("") do |output, tok|
      output += tok.parse(data)
    end  
  end
end

# Main wrapper for Lexing + Parsing.
class Wikistache
  def self.parse(str, data = {})
    toks = Lexer.lex(str)
    Parser.parse(toks, data)
  end
end
