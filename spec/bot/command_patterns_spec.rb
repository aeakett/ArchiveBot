require 'spec_helper'

require 'bot/command_patterns'

describe CommandPatterns do
  describe 'Archive command' do
    let(:regex) { CommandPatterns::ARCHIVE }

    it 'recognizes !archive URL' do
      md = regex.match "!archive http://www.example.com/"

      md[1].should == 'http://www.example.com/'
    end

    it 'recognizes !a URL' do
      md = regex.match "!a http://www.example.com/"

      md[1].should == 'http://www.example.com/'
    end

    it 'recognizes !a URL--ignores=blogs as a URL' do
      md = regex.match "!a http://www.example.com/--ignores=blogs"

      md[1].should == 'http://www.example.com/--ignores=blogs'
    end

    it 'recognizes !a URL --ignores=blogs' do
      md = regex.match "!a http://www.example.com/ --ignores=blogs"

      md[1].should == 'http://www.example.com/'
      md[2].should == '--ignores=blogs'
    end

    it 'recognizes !a URL --ignores=blogs --someother=param' do
      md = regex.match "!a http://www.example.com/ --ignores=blogs --someother=param"

      md[1].should == 'http://www.example.com/'
      md[2].should == '--ignores=blogs --someother=param'
    end
  end

  describe 'Archiveonly command' do
    let(:regex) { CommandPatterns::ARCHIVEONLY }

    it 'recognizes !archiveonly URL' do
      md = regex.match "!archiveonly http://www.example.com/"

      md[1].should == 'http://www.example.com/'
    end

    it 'recognizes !ao URL' do
      md = regex.match "!ao http://www.example.com/"

      md[1].should == 'http://www.example.com/'
    end

    it 'recognizes !ao URL--ignores=blogs as a URL' do
      md = regex.match "!ao http://www.example.com/--ignores=blogs"

      md[1].should == 'http://www.example.com/--ignores=blogs'
    end

    it 'recognizes !ao URL --ignores=blogs' do
      md = regex.match "!ao http://www.example.com/ --ignores=blogs"

      md[1].should == 'http://www.example.com/'
      md[2].should == '--ignores=blogs'
    end

    it 'recognizes !ao URL --ignores=blogs --someother=param' do
      md = regex.match "!ao http://www.example.com/ --ignores=blogs --someother=param"

      md[1].should == 'http://www.example.com/'
      md[2].should == '--ignores=blogs --someother=param'
    end
  end

  shared_examples_for 'a set delay command' do |cmd|
    it "recognizes #{cmd} IDENT MIN MAX" do
      md = regex.match "#{cmd} f4pg9usx4j96ki3zczwlczu51 500 750"

      md[1].should == 'f4pg9usx4j96ki3zczwlczu51'
      md[2].should == '500'
      md[3].should == '750'
    end

    it "recognizes #{cmd} IDENT MIN MAX with non-integral numbers" do
      md = regex.match "#{cmd} f4pg9usx4j96ki3zczwlczu51 500.5 751.5"

      md[1].should == 'f4pg9usx4j96ki3zczwlczu51'
      md[2].should == '500.5'
      md[3].should == '751.5'
    end

    it "does not recognize negative delays" do
      md = regex.match "#{cmd} f4pg9usx4j96ki3zczwlczu51 500.5 -751.5"

      md.should be_nil
    end
  end

  describe 'Set delay command' do
    let(:regex) { CommandPatterns::SET_DELAY }

    it_should_behave_like 'a set delay command', '!delay'
    it_should_behave_like 'a set delay command', '!d'
  end

  describe 'Set page requisite delay command' do
    let(:regex) { CommandPatterns::SET_PAGEREQ_DELAY }

    it_should_behave_like 'a set delay command', '!reqdelay'
    it_should_behave_like 'a set delay command', '!reqd'
  end

  describe 'Archiveonly-many command' do
    let(:regex) { CommandPatterns::ARCHIVEONLY_MANY }

    it 'recognizes !ao < SOURCE' do
      md = regex.match '!ao < http://pastebin.com/123456'

      md[1].should == 'http://pastebin.com/123456'
    end

    it 'recognizes !ao<SOURCE' do
      md = regex.match '!ao<http://pastebin.com/123456'

      md[1].should == 'http://pastebin.com/123456'
    end

    it 'recognizes !ao<SOURCE --ignores=blogs' do
      md = regex.match '!ao<http://pastebin.com/123456 --ignores=blogs'

      md[1].should == 'http://pastebin.com/123456'
      md[2].should == '--ignores=blogs'
    end
  end
end
