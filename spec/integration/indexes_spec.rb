require 'spec_helper'

describe Departure, integration: true do
  class Comment < ActiveRecord::Base; end

  let(:migration_fixtures) do
    ActiveRecord::MigrationContext.new([MIGRATION_FIXTURES], ActiveRecord::SchemaMigration).migrations
  end

  let(:migration_paths) { [MIGRATION_FIXTURES] }

  let(:direction) { :up }

  context 'managing indexes' do
    let(:version) { 2 }

    context 'adding indexes' do
      let(:direction) { :up }

      # TODO: Create it directly like this?
      before do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          1
        ).migrate
      end

      it 'executes the percona command' do
        expect_percona_command('ADD INDEX `index_comments_on_some_id_field` (`some_id_field`)')

        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version
        ).migrate

        expect(:comments).to have_index('index_comments_on_some_id_field')
      end

      it 'marks the migration as up' do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version
        ).migrate

        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end
    end

    context 'removing indexes' do
      let(:direction) { :down }

      before do
        ActiveRecord::Migrator.new(
          :up,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          1
        ).migrate

        ActiveRecord::Migrator.new(
          :up,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version
        ).migrate
      end

      it 'executes the percona command' do
        expect_percona_command('DROP INDEX `index_comments_on_some_id_field`')

        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version - 1
        ).migrate

        expect(:comments).not_to have_index('index_comments_on_some_id_field')
      end

      it 'marks the migration as down' do
        ActiveRecord::Migrator.new(
          direction,
          migration_fixtures,
          ActiveRecord::SchemaMigration,
          version - 1
        ).migrate

        expect(ActiveRecord::Migrator.current_version).to eq(1)
      end
    end

    context 'renaming indexes' do
      let(:direction) { :up }
      let(:version) { 13 }

      before do
        ActiveRecord::Migrator.new(:up, migration_fixtures, ActiveRecord::SchemaMigration, 2).migrate
      end

      it 'executes the percona command' do
        if ActiveRecord::Base.connection.send(:supports_rename_index?)
          expect_percona_command('RENAME INDEX `index_comments_on_some_id_field` TO `new_index_comments_on_some_id_field`')
        else
         expect_percona_command('ADD INDEX `new_index_comments_on_some_id_field` (`some_id_field`)')
         expect_percona_command('DROP INDEX `index_comments_on_some_id_field`')
        end

        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(:comments).to have_index('new_index_comments_on_some_id_field')
      end

      it 'marks the migration as up' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end
    end
  end

  context 'adding/removing unique indexes' do
    let(:version) { 3 }

    context 'adding indexes' do
      let(:direction) { :up }

      before do
        ActiveRecord::Migrator.new(:up, migration_fixtures, ActiveRecord::SchemaMigration,1).migrate
      end

      it 'executes the percona command' do
        expect_percona_command('ADD UNIQUE INDEX `index_comments_on_some_id_field` (`some_id_field`)')

        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)

        expect(unique_indexes_from(:comments))
          .to match_array(['index_comments_on_some_id_field'])
      end

      it 'marks the migration as up' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end
    end

    context 'removing indexes' do
      let(:direction) { :down }

      before do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(:up, 1)
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(:up, version)
      end

      it 'executes the percona command' do
        expect_percona_command('DROP INDEX `index_comments_on_some_id_field`')

        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)

        expect(unique_indexes_from(:comments))
          .not_to match_array(['index_comments_on_some_id_field'])
      end

      it 'marks the migration as down' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
        expect(ActiveRecord::Migrator.current_version).to eq(1)
      end
    end
  end

  def expect_percona_command(command)
    # Add addional escaping to backticks here to keep the spec more readable.
    command = command.gsub(/`/, '\\\`')

    expect(Open3).
      to receive(:popen3).
      with(a_string_matching(/\Apt-online-schema-change .+--alter "#{Regexp.escape(command)}"/)).
      and_call_original
  end
end
