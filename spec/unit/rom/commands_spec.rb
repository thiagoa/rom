require 'spec_helper'

describe 'Commands' do
  include_context 'gateway only'
  include_context 'users and tasks'

  let(:users_relation) do
    Class.new(ROM::Memory::Relation) do
      def by_id(id)
        restrict(id: id)
      end
    end.new(users_dataset)
  end

  describe '.build_class' do
    it 'creates a command class constant' do
      klass = ROM::ConfigurationDSL::Command.build_class(:create, :users, adapter: :memory) {
        def super?
          true
        end
      }

      expect(klass.name).to eql('ROM::Memory::Commands::Create[Users]')
      expect(klass.register_as).to eql(:create)

      command = klass.build(users_relation)

      expect(command).to be_a(ROM::Memory::Commands::Create)
      expect(command).to be_super
    end
  end

  describe '.build' do
    it 'returns create command when type is set to :create' do
      klass = Class.new(ROM::Commands::Create[:memory]) do
        relation :users
      end

      command = klass.build(users_relation)

      expect(command).to be_kind_of(ROM::Memory::Commands::Create)
    end

    it 'returns update command when type is set to :update' do
      klass = Class.new(ROM::Commands::Update[:memory]) do
        relation :users
      end

      command = klass.build(users_relation)

      expect(command).to be_kind_of(ROM::Memory::Commands::Update)
    end

    it 'returns delete command when type is set to :delete' do
      klass = Class.new(ROM::Commands::Delete[:memory]) do
        relation :users
      end

      command = klass.build(users_relation)

      expect(command).to be_kind_of(ROM::Memory::Commands::Delete)
    end
  end

  describe '#>>' do
    let(:users) { double('users') }
    let(:tasks) { double('tasks') }
    let(:logs) { [] }

    it 'composes two commands' do
      user_input = { name: 'Jane' }
      user_tuple = { user_id: 1, name: 'Jane' }

      task_input = { title: 'Task One' }
      task_tuple = { user_id: 1, title: 'Task One' }

      create_user = Class.new(ROM::Commands::Create) {
        def execute(user_input)
          relation.insert(user_input)
        end
      }.build(users)

      create_task = Class.new(ROM::Commands::Create) {
        def execute(task_input, user_tuple)
          relation.insert(task_input.merge(user_id: user_tuple[:user_id]))
        end
      }.build(tasks)

      create_log = Class.new(ROM::Commands::Create) {
        result :one

        def execute(task_tuple)
          relation << task_tuple
        end
      }.build(logs)

      command = create_user.curry(user_input)
      command >>= create_task.curry(task_input)
      command >>= create_log

      expect(users).to receive(:insert).with(user_input).and_return(user_tuple)
      expect(tasks).to receive(:insert).with(task_tuple).and_return(task_tuple)

      result = command.call

      expect(result).to eql(task_tuple)
      expect(logs).to include(task_tuple)
    end

    it 'forwards methods to the left' do
      user_input = { name: 'Jane' }
      user_tuple = { user_id: 1, name: 'Jane' }

      create_user = Class.new(ROM::Commands::Create) {
        def execute(user_input)
          relation.insert(user_input)
        end
      }.build(users)

      command = create_user >> proc {}

      expect(users).to receive(:insert).with(user_input).and_return(user_tuple)

      command.with(user_input).call
    end
  end
end
