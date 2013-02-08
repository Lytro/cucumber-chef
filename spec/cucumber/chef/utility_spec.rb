require 'spec_helper'

describe Cucumber::Chef::Utility do
  describe '#knife_rb' do
    let(:file_cache) { 'tmp/rspec' }

    let(:provider) { 'test' }

    before do
      Cucumber::Chef.stub(:home_dir).and_return(file_cache)
      Cucumber::Chef::Config.stub(:provider).and_return(provider)
    end

    it 'creates the file if it does not exist' do
      Cucumber::Chef.knife_rb
      File.exist?(File.join(file_cache, provider, "knife.rb")).should be_true
    end

    it 'does not modify the contents if it exists' do
      FileUtils.mkdir_p(File.join(file_cache, provider))
      File.open(File.join(file_cache, provider, 'knife.rb'), 'a') do |f|
        f.puts 'Test contents.'
      end

      Cucumber::Chef.knife_rb

      File.open(File.join(file_cache, provider, 'knife.rb'), 'r') do |f|
        f.gets.should eq %Q{Test contents.\n}
      end
    end
  end
end
