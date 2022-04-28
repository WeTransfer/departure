require 'spec_helper'

describe Departure, integration: true do
  class Comment < ActiveRecord::Base; end

  let(:migration_fixtures) do
    ActiveRecord::MigrationContext.new([MIGRATION_FIXTURES], ActiveRecord::SchemaMigration).migrations.select do |m|
      m.version == version
    end
  end
  let(:direction) { :up }

  context 'change_table' do
    let(:version) { 28 }

    def column_metadata(table, name)
      ActiveRecord::Base.connection.columns(table).detect { |c| c.name == name.to_s }
    end

    context 'creating column' do
      before(:each) do
        ActiveRecord::Migrator.new(direction, migration_fixtures, ActiveRecord::SchemaMigration, version).migrate
      end

      it 'adds the column in the DB table' do
        expect(:comments).to have_column('boring_id_field')
        expect(:comments).to have_column('other_boring_id_field')
        expect(:comments).to have_column('hello')
      end

      it 'adds timestmaps' do
        expect(:comments).to have_column('created_at')
        expect(:comments).to have_column('updated_at')
      end

      it 'renames columns' do
        expect(:comments).to have_column('renamed_id_field')
      end

      it 'marks the migration as up' do
        expect(ActiveRecord::Migrator.current_version).to eq(version)
      end

      it 'changes column' do
        col = column_metadata(:comments, :hello)
        expect(col.type).to eql(:integer)
      end
    end
  end
end
