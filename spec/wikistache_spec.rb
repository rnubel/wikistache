require 'rspec'

load 'wikistache.rb'


describe "Lexer" do
  it "should lex a string with only one string token" do
    toks = Lexer.lex("This is a string")
    toks.size.should == 1
    toks.first.should == StringToken.new("This is a string")
  end

  
  it "should lex a string with one var token" do
    toks = Lexer.lex("This is a [SomeType] of string")
    toks.size.should == 3
    toks.first.should == StringToken.new("This is a ")
    toks[1].should == VariableToken.new("SomeType")
    toks.last.should == StringToken.new(" of string")
  end

  it "should lex a string with two consecutive var tokens" do
    toks = Lexer.lex("This is a [SomeType][Other Type] of string")
    toks.size.should == 4
    toks.first.should == StringToken.new("This is a ")
    toks.last.should == StringToken.new(" of string")
  end

  it "should lex a string with two non-consecutive var tokens" do
    toks = Lexer.lex("This is a [SomeType] of [Other Type] of string")
    toks.size.should == 5
    toks.first.should == StringToken.new("This is a ")
    toks[2].should == StringToken.new(" of ")
    toks[3].should == VariableToken.new("Other Type")
    toks.last.should == StringToken.new(" of string")
  end

  it "should not die on a syntax error" do
    lambda {Lexer.lex("This is a [Malformed string")}.should_not raise_error
  end

  it "should lex a conditional with no nested tags" do
    toks = Lexer.lex("This is a [If test][EndIf] conditional.")
    toks.size.should == 3
    toks[1].is_a?(ConditionalToken).should == true
  end

  it "should lex a conditional with a nested string" do
    toks = Lexer.lex("This is a [If test]true[EndIf] conditional.")
    toks.size.should == 3
    toks[1].is_a?(ConditionalToken).should == true
    # poor testing ahead
    toks[1].parse({}).should == ""
    toks[1].parse({:test => true}).should == "true"
  end

  it "should lex a nested conditional" do
    toks = Lexer.lex("[If yes]Is [If no]that so [EndIf]that the case?[EndIf]")
    toks.size.should == 1
    # more poor testing. should examine internals
    toks[0].parse({}).should == ""
    toks[0].parse({:yes => true}).should =="Is that the case?"
    toks[0].parse({:yes => true, :no => true}).should =="Is that so that the case?"
  end
end

describe "Parser" do
  it "should parse a single string token" do
    Parser.parse([StringToken.new("Test")]).should == "Test"
  end

  it "should parse two string tokens" do
    Parser.parse([StringToken.new("Test"), StringToken.new(" Bar")]).should == "Test Bar"
  end

  it "should handle parsing a variable token with unknown variable" do
    Parser.parse([StringToken.new("Test "), VariableToken.new("lol"), StringToken.new(" Bar")]).should == "Test Unknown Bar"
  end

  it "should handle parsing a variable token with known variable" do
    Parser.parse([StringToken.new("Test "), VariableToken.new("lol"), StringToken.new(" Bar")], {:lol => "Is"}).should == "Test Is Bar"
  end

  it "should handle parsing a two-key variable token with known variable" do
    Parser.parse([StringToken.new("Test "), VariableToken.new("test:lol"), StringToken.new(" Bar")], {:test => {:lol => "Is"}}).should == "Test Is Bar"
  end
 
   it "should handle parsing a two-key variable token with known variable even if varname is given in title case" do
    Parser.parse([StringToken.new("Test "), VariableToken.new("Test:Lol"), StringToken.new(" Bar")], {:test => {:lol => "Is"}}).should == "Test Is Bar"
  end
end

describe "Wikistache" do
  before(:all) do
    @data = {
              :customer => {
                              :first_name => "Billy",
                              :last_name => "Joel"
                           },
              :loan =>  {
                              :amount_due => 100
                        }
            }

  end

  it "should parse a string without data" do
    str = "This is a [test]"
    Wikistache.parse(str).should == "This is a Unknown"
  end

  it "should parse a complex-ish string" do
    str = "Hello [Customer:First_Name] [Customer:Last_Name]! We at CNU appreciate how you still haven't paid back $[Loan:Amount_Due] on your loan. Hurry it up already, [Customer:First_Name]."
    Wikistache.parse(str, @data).should == "Hello Billy Joel! We at CNU appreciate how you still haven't paid back $100 on your loan. Hurry it up already, Billy."
  end
end
