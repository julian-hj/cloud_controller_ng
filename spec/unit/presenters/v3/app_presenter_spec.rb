require 'spec_helper'
require 'presenters/v3/app_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe AppPresenter do
    let(:app) do
      VCAP::CloudController::AppModel.make(
        environment_variables: { 'some' => 'stuff' },
        desired_state: 'STOPPED',
      )
    end

    before do
      app.lifecycle_data.update(
        buildpack: 'git://user@github.com:repo',
        stack: 'the-happiest-stack',
      )
    end

    describe '#to_hash' do
      let(:result) { AppPresenter.new(app).to_hash }

      it 'presents the app as json' do
        app.add_process({ app: app, instances: 4 })

        expect(result[:guid]).to eq(app.guid)
        expect(result[:name]).to eq(app.name)
        expect(result[:desired_state]).to eq(app.desired_state)
        expect(result[:environment_variables]).to eq(app.environment_variables)
        expect(result[:total_desired_instances]).to eq(4)
        expect(result[:created_at]).to be_a(Time)
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:links]).to include(:droplet)
        expect(result[:links]).to include(:start)
        expect(result[:links]).to include(:stop)
        expect(result[:lifecycle][:type]).to eq('buildpack')
        expect(result[:lifecycle][:data][:stack]).to eq('the-happiest-stack')
        expect(result[:lifecycle][:data][:buildpack]).to eq('git://user@github.com:repo')
      end

      context 'if there are no processes' do
        it 'returns 0' do
          expect(result[:total_desired_instances]).to eq(0)
        end
      end

      context 'if environment_variables are not present' do
        before { app.environment_variables = {} }

        it 'returns an empty hash as environment_variables' do
          expect(result[:environment_variables]).to eq({})
        end
      end

      context 'links' do
        it 'includes start and stop links' do
          app.environment_variables = { 'some' => 'stuff' }

          expect(result[:links][:start][:method]).to eq('PUT')
          expect(result[:links][:stop][:method]).to eq('PUT')
        end

        it 'includes route_mappings links' do
          expect(result[:links][:route_mappings][:href]).to eq("/v3/apps/#{app.guid}/route_mappings")
        end

        it 'includes tasks links' do
          expect(result[:links][:tasks][:href]).to eq("/v3/apps/#{app.guid}/tasks")
        end

        context 'droplets' do
          before do
            app.droplet = VCAP::CloudController::DropletModel.make(guid: '123')
          end

          it 'includes a link to the current droplet' do
            expect(result[:links][:droplet][:href]).to eq("/v3/apps/#{app.guid}/droplets/current")
          end

          it 'includes a link to the droplets if present' do
            VCAP::CloudController::DropletModel.make(app: app, state: 'PENDING')
            expect(result[:links][:droplets][:href]).to eq("/v3/apps/#{app.guid}/droplets")
          end
        end
      end

      context 'when show_secrets is false' do
        let(:result) { AppPresenter.new(app, show_secrets: false).to_hash }

        it 'redacts the environment_variables' do
          expect(result[:environment_variables]).to eq({ 'redacted_message' => '[PRIVATE DATA HIDDEN]' })
        end
      end
    end
  end
end
