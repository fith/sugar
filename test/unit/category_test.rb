require 'test_helper'

class CategoryTest < ActiveSupport::TestCase
	should_have_many :discussions
	should_validate_presence_of :name
	
	context "A series of categories" do
		setup do
			5.times { Category.make }
		end
		should "be created" do
			assert_equal 5, Category.count(:all)
		end
		should "act as a list" do
			categories = Category.find(:all, :order => 'position ASC')
			assert_equal 1, categories[0].position
			assert_equal 5, categories[4].position
			categories.each do |c|
				assert_equal categories.index(c) + 1, c.position
			end
		end
	end
	
	context "A category" do
		setup do
			@category = Category.make(:name => 'This is my Category')
		end
		should "slug urls" do
			Category.work_safe_urls = false
			assert @category.to_param =~ /^[\d]+;This\-is\-my\-Category$/
			Category.work_safe_urls = true
			assert @category.to_param =~ /^[\d]+$/
		end
	end
	
	context "A trusted category" do
		setup do
			@category = Category.make(:trusted => true)
		end
		should "be trusted" do
			assert @category.trusted?
		end
		should "not show up on trusted = 0" do
			assert_equal 1, Category.count(:all)
			assert_equal 0, Category.count(:all, :conditions => ['trusted = 0'])
		end
		should "not be viewable by a regular user" do
			assert !@category.viewable_by?(User.make)
		end
		should "should be viewable by a trusted user" do
			assert @category.viewable_by?(User.make(:trusted))
		end
		should "should be viewable by an admin" do
			assert @category.viewable_by?(User.make(:admin))
		end
		context "with 45 discussions" do
			setup do
				@category = Category.make(:trusted => true)
				45.times { @category.discussions.make }
			end
			should "report proper count" do
				assert_equal 45, @category.discussions.count
			end
			should "have only trusted discussions" do
				assert_equal 0,  Discussion.count(:all, :conditions => ['trusted = 0'])
				assert_equal 45, Discussion.count(:all, :conditions => ['trusted = 1'])
			end
			should "update trusted flag on discussions" do
				@category.update_attribute(:trusted, false)
				assert !@category.trusted?
				assert_equal 45, Discussion.count(:all, :conditions => ['trusted = 0'])
				assert_equal 0,  Discussion.count(:all, :conditions => ['trusted = 1'])
				@category.update_attribute(:trusted, true)
				assert @category.trusted?
				assert_equal 0,  Discussion.count(:all, :conditions => ['trusted = 0'])
				assert_equal 45, Discussion.count(:all, :conditions => ['trusted = 1'])
			end
		end
	end
end
