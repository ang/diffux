require 'spec_helper'

describe SnapshotsController do
  render_views

  describe '#show' do
    let(:snapshot) { create(:snapshot) }
    subject        { get :show, id: snapshot.to_param }

    it         { should be_success }
    its(:body) { should include('Snapshot image') }
    its(:body) { should include('Under review') }

    context 'with a snapshot in pending state' do
      before { snapshot.update_attributes(external_image_id: nil) }

      it         { should be_success }
      its(:body) { should_not include('Snapshot image') }
      its(:body) { should include('Pending') }
      its(:body) { should_not include('Under review') }
    end
  end

  describe '#create' do
    let(:external_image_id) { rand(100) }
    let(:title)             { rand(100_000).to_s }
    let(:url)               { create :url }

    before do
      Snapshotter.any_instance.stubs(:take_snapshot!).returns(
        title:              title,
        external_image_id:  external_image_id
      )

      SnapshotComparer.any_instance.stubs(:compare!).returns(
        diff_image:      ChunkyPNG::Image.new(10, 10, ChunkyPNG::Color::WHITE),
        diff_in_percent: 0.001
      )
    end

    subject do
      post :create, url: url.to_param
      response
    end

    it 'adds a snapshot' do
      expect { subject }.to change { Snapshot.count }.by(1)
    end

    it 'captures the snapshot title' do
      subject
      snapshot = Snapshot.unscoped.last
      snapshot.title.should == title
    end

    context 'with a baseline' do
      before do
        create(:snapshot, :accepted, url: url)
      end

      it 'adds a snapshot' do
        expect { subject } .to change { Snapshot.count }.by(1)
      end
    end
  end

  describe '#destroy' do
    let!(:snapshot) { create(:snapshot) }

    it 'removes a snapshot' do
      expect { delete :destroy, id: snapshot.to_param }
        .to change { Snapshot.count }.by(-1)
    end
  end

  describe '#accept' do
    let!(:snapshot) { create(:snapshot) }

    it 'accepts the snapshot' do
      expect { post :accept, id: snapshot.to_param }
        .to change { snapshot.reload.accepted? }.to(true)
    end
  end

  describe '#reject' do
    let!(:snapshot) { create(:snapshot) }

    it 'rejects the snapshot' do
      expect { post :reject, id: snapshot.to_param }
        .to change { snapshot.reload.rejected? }.to(true)
    end
  end
end
