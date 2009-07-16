require 'test_helper'

class UnionizerTest < ActiveSupport::TestCase
  
  def setup
    @post, @other_post = Factory(:post), Factory(:post)
    @post_without_category = Factory(:post, :category_id => nil)
  end
  
  def test_should_find_with_union
    posts = Post.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:category_id => @other_post.category_id}}
    ])
    assert_same_elements([@post, @other_post], posts)
  end
  
  def test_should_find_with_union_and_shared_conditionals
    posts = Post.all(:union => [
      {:conditions => {:user_id => @post_without_category.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ], :conditions => "category_id is not null")
    assert_same_elements([@other_post], posts)
  end
  
  def test_should_find_with_ordered_union
    posts = Post.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ], :order => "category_id")
    assert_equal([@post, @other_post].sort_by(&:category_id), posts)
  end
  
  def test_should_find_with_limited_union
    posts = Post.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ], :limit => 1)
    assert_equal([@post], posts)
  end
  
  def test_should_find_with_limited_ordered_union
    posts = Post.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ], :limit => 1, :order => 'category_id DESC')
    assert_equal([@other_post], posts)
  end
  
  def test_should_find_with_scoped_order
    posts = Post.recent.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ])
    assert_equal([@other_post, @post], posts)
  end
  
  def test_should_find_with_scoped_limit
    posts = Post.latest.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ])
    assert_equal([@post], posts)
  end
  
  def test_should_find_with_scoped_order_and_limit
    posts = Post.recent.latest.all(:union => [
      {:conditions => {:user_id => @post.user_id}},
      {:conditions => {:user_id => @other_post.user_id}}
    ])
    assert_equal([@other_post], posts)
  end
  
  def test_should_find_with_internal_limit
    posts = Post.all(:union => [
      {:conditions => {:user_id => @post_without_category.user_id}},
      {:conditions => {:category_id => [@post.category_id, @other_post.category_id]}, :limit => 1}
    ])
    assert_same_elements([@post, @post_without_category], posts)
  end
  
  def test_should_find_with_normal_conditions
    posts = Post.all(
      {:conditions => {:user_id => @post.user_id}}
    )
    assert_equal([@post], posts)
  end
  
  def test_should_find_with_normal_scope
    posts = Post.recent.all
    assert_equal([@other_post, @post, @post_without_category], posts)
  end
  
  def teardown
    Post.delete_all
  end
  
end