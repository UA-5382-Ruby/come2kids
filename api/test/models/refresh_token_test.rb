require "test_helper"
require "timeout"

class RefreshTokenTest < ActiveSupport::TestCase
  include AuthenticationHelpers

  setup do
    @user = create_user
  end

  test "issued tokens store only a digest and expire" do
    token, raw_token = RefreshToken.issue_for(@user)

    assert_equal token, RefreshToken.find_by_raw(raw_token)
    assert_equal RefreshToken.digest(raw_token), token.token_digest
    assert_not_equal raw_token, token.token_digest
    assert_predicate token, :active?
    token.update!(expires_at: Time.current)
    assert_predicate token, :expired?
    assert_nil token.rotate!
  end

  test "revoked tokens cannot rotate again" do
    token, = RefreshToken.issue_for(@user)
    successor, raw_token = token.rotate!

    assert_equal successor, token.reload.replaced_by
    assert_equal successor, RefreshToken.find_by_raw(raw_token)
    assert_predicate token, :revoked?
    assert_predicate successor, :active?
    assert_no_difference "RefreshToken.where(user: @user).count" do
      assert_nil token.rotate!
    end
  end

  test "concurrent rotations issue exactly one successor" do
    token, = RefreshToken.issue_for(@user)
    ready = Queue.new
    start = Queue.new
    workers = 2.times.map do
      database_worker do
        current = RefreshToken.find(token.id)
        ready << true
        start.pop(timeout: 5) || raise("rotation start timed out")
        current.rotate!
      end
    end
    2.times { assert ready.pop(timeout: 5), "rotation worker did not become ready" }
    2.times { start << true }
    results = workers.map { |worker| worker_value(worker) }

    assert_equal 1, results.count(&:nil?)
    successor, raw_token = results.compact.fetch(0)
    assert_equal successor, token.reload.replaced_by
    assert_equal successor, RefreshToken.find_by_raw(raw_token)
    assert_equal [ successor.id ], RefreshToken.active.where(user: @user).pluck(:id)
  ensure
    stop_workers(workers)
  end

  test "bulk revocation waits for rotation and includes its uncommitted successor" do
    token, = RefreshToken.issue_for(@user)
    inserted = Queue.new
    release = Queue.new
    revoker_pid = Queue.new
    rotation = database_worker do
      rotation_thread = Thread.current
      callback = lambda do |event|
        if Thread.current == rotation_thread && event.payload[:name] == "RefreshToken Create"
          inserted << true
          release.pop(timeout: 5) || raise("rotation release timed out")
        end
      end
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        RefreshToken.find(token.id).rotate!
      end
    end
    assert inserted.pop(timeout: 5), "rotation did not insert a successor"

    revocation = database_worker do
      revoker_pid << ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
      RefreshToken.revoke_all_for(User.find(@user.id))
    end
    pid = revoker_pid.pop(timeout: 5)
    assert pid, "revocation worker did not become ready"
    ActiveRecord::Base.uncached do
      Timeout.timeout(5) do
        until ActiveRecord::Base.connection.select_value("SELECT cardinality(pg_blocking_pids(#{Integer(pid)})) > 0")
          sleep 0.01
        end
      end
    end
    release << true
    successor, = worker_value(rotation)
    worker_value(revocation)

    assert_predicate token.reload, :revoked?
    assert_predicate successor.reload, :revoked?
    assert_empty RefreshToken.active.where(user: @user)
  ensure
    release << true if release
    stop_workers([ rotation, revocation ])
  end

  test "user queries retain their composite index without a redundant user index" do
    indexes = ActiveRecord::Base.connection.indexes(:refresh_tokens)

    assert indexes.any? { |index| index.columns == %w[user_id revoked_at] }
    assert_not indexes.any? { |index| index.columns == %w[user_id] }
  end

  private

  def database_worker(&block)
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection(prevent_permanent_checkout: true) do |connection|
        connection.execute("SET lock_timeout = '5s'")
        block.call
      ensure
        connection.execute("RESET lock_timeout")
      end
    end
  end

  def worker_value(worker)
    assert worker.join(10), "database worker did not finish"
    worker.value
  end

  def stop_workers(workers)
    Array(workers).compact.each do |worker|
      worker.kill if worker.alive?
      worker.join
    end
  end
end
