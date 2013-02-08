require 'spec_helper'

describe Cucumber::Chef::Utility do
  describe '#init_knife_rb' do
    let(:file_cache) { 'tmp/rspec' }

    let(:provider) { 'test' }

    let(:username) { 'test_user' }

    before do
      Cucumber::Chef.stub(:home_dir).and_return(file_cache)
      Cucumber::Chef::Config.stub(:provider).and_return(provider)
      Cucumber::Chef::Config.stub(:user).and_return(username)
      Cucumber::Chef::Config.stub(:librarian_chef).and_return('true')
    end

    it 'creates the file if it does not exist' do
      Cucumber::Chef.init_knife_rb
      File.exist?(File.join(file_cache, provider, 'knife.rb')).should be_true
    end

    it 'does not modify the contents if it exists' do
      FileUtils.mkdir_p(File.join(file_cache, provider))
      File.open(File.join(file_cache, provider, 'knife.rb'), 'a') do |f|
        f.puts 'Test contents.'
      end

      Cucumber::Chef.init_knife_rb

      File.open(File.join(file_cache, provider, 'knife.rb'), 'r') do |f|
        f.gets.should eq %Q{Test contents.\n}
      end
    end
  end
end
