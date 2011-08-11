require 'helper'
require 'tempfile'

describe Pry do

  before do
    Readline::HISTORY.shift while Readline::HISTORY.length > 0
    @hist = Tempfile.new(["tmp", ".pry_history"]).tap(&:close).path
    File.open(@hist, 'w') {|f| f << "1\n2\n3\n" }
    @old_hist = Pry.config.history.file
    Pry.config.history.file = @hist
    Pry.load_history
  end

  after do
    File.unlink @hist
    Pry.config.history.file = @old_hist
  end

  describe ".load_history" do
    it "should read the contents of the file" do
      Readline::HISTORY.to_a[-2..-1].should === ["2", "3"]
    end
  end

  describe ".save_history" do
    it "should include a trailing newline" do
      Readline::HISTORY << "4"
      Pry.save_history
      File.read(@hist).should =~ /4\n\z/
    end

    it "should not change anything if history is not changed" do
      File.open(@hist, 'w') {|f| f << "4\n5\n6\n" }
      Pry.save_history
      File.read(@hist).should == "4\n5\n6\n"
    end

    it "should append new lines to the file" do
      Readline::HISTORY << "4"
      Pry.save_history
      File.read(@hist).should == "1\n2\n3\n4\n"
    end

    it "should not clobber lines written by other Pry's in the meantime" do
      Readline::HISTORY << "5"
      File.open(@hist, 'a') {|f| f << "4\n" }
      Pry.save_history

      Readline::HISTORY.to_a[-3..-1].should == ["2", "3", "5"]
      File.read(@hist).should == "1\n2\n3\n4\n5\n"
    end

    it "should not delete lines from the file if this session's history was cleared" do
      Readline::HISTORY.pop while Readline::HISTORY.size > 0
      Pry.save_history
      File.read(@hist).should == "1\n2\n3\n"
    end

    it "should save new lines that are added after the history was cleared" do
      Readline::HISTORY.pop while Readline::HISTORY.size > 0
      Readline::HISTORY << "4"

      # doing this twice as libedit on 1.8.7 has bugs and sometimes ignores the
      # first line in history
      Readline::HISTORY << "4"
      Pry.save_history
      File.read(@hist).should =~ /1\n2\n3\n4\n/
    end

    it "should only append new lines the second time it is saved" do
      Readline::HISTORY << "4"
      Pry.save_history
      File.open(@hist, 'a') {|f| f << "5\n" }
      Readline::HISTORY << "6"
      Pry.save_history

      Readline::HISTORY.to_a[-4..-1].should == ["2", "3", "4", "6"]
      File.read(@hist).should == "1\n2\n3\n4\n5\n6\n"
    end
  end
end
