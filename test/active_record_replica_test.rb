# frozen_string_literal: true

require_relative "test_helper"

#
# Unit Test for active_record_replica
#
# Since there is no database replication in this test environment, it will
# use 2 separate databases. Writes go to the first database and reads to the second.
# As a result any writes to the first database will not be visible when trying to read from
# the second test database.
#
# The tests verify that reads going to the replica database do not find data written to the primary.
class ActiveRecordReplicaTest < Minitest::Test
  describe "the active_record_replica gem" do
    let(:user_name) { "Joe Bloggs" }
    let(:address) { "Somewhere" }
    let(:user) { User.new(name: user_name, address: address) }

    before do
      ActiveRecordReplica.ignore_transactions = false
      User.delete_all
    end

    it "saves to primary" do
      user.save!
    end

    it "saves to primary, read from replica" do
      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count

      # Write to primary
      user.save!

      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count
    end

    it "save to primary, read from primary when in a transaction" do
      assert_equal false, ActiveRecordReplica.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Primary
        assert_equal 0, User.where(name: user_name, address: address).count

        # Write to primary
        user.save!

        # Read from Primary
        assert_equal 1, User.where(name: user_name, address: address).count
      end

      # Read from Non-replicated replica
      assert_equal 0, User.where(name: user_name, address: address).count
    end

    it "save to primary, read from replica when ignoring transactions" do
      ActiveRecordReplica.ignore_transactions = true
      assert ActiveRecordReplica.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Primary
        assert_equal 0, User.where(name: user_name, address: address).count

        # Write to primary
        user.save!

        # Read from Non-replicated replica
        assert_equal 0, User.where(name: user_name, address: address).count
      end

      # Read from Non-replicated replica
      assert_equal 0, User.where(name: user_name, address: address).count
    end

    it "saves to primary, force a read from primary even when _not_ in a transaction" do
      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count

      # Write to primary
      user.save!

      # Read from replica
      assert_equal 0, User.where(name: user_name, address: address).count

      # Read from Primary
      ActiveRecordReplica.read_from_primary do
        assert_equal 1, User.where(name: user_name, address: address).count
      end
    end
  end
end
