# frozen_string_literal: true

require "spec_helper"

FIXTURES_DIR = "spec/fixtures"
PERF_RESULTS_FIXTURES_DIR = "#{FIXTURES_DIR}/perf_results_helper"
PUPPET_METRICS_FIXTURES_DIR = "#{FIXTURES_DIR}/puppet-metrics-collector"

TEST_METRICS_RESULTS_DIR = "#{PERF_RESULTS_FIXTURES_DIR}/scale/PERF_SCALE_12345/Scale_12345_1_1500/metric"
TEST_METRICS_RESULTS_NAME = File.basename(TEST_METRICS_RESULTS_DIR)
TEST_STATS_PATH = "#{TEST_METRICS_RESULTS_DIR}/js/stats.json"
TEST_INVALID_STATS_PATH = "#{TEST_METRICS_RESULTS_DIR}/js/invalid_stats.json"
TEST_INVALID_STATS_MISSING_NAME = "node"
TEST_STATS_NUMBER_OF_KEYS = 6

TEST_VALID_CSV_HEADINGS_PATH = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/headings_row.csv"
TEST_VALID_CSV_PATH = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/01.csv"
TEST_VALID_HTML_PATH = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/01.csv.html"

TEST_INVALID_CSV_PATH = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/not_a_csv_file.txt"

TEST_HTML_TABLE = <<-TEST_HTML_TABLE
  <table class="table table-bordered">
    <tr>
      <th>a</th>
      <th>b</th>
      <th>c</th>
    </tr>
    <tr>
      <td>1</td>
      <td>2</td>
      <td>3</td>
    </tr>
  </table>
TEST_HTML_TABLE

TEST_JSON_NO_CATALOG = <<~TEST_JSON
  {
      "timestamp": "2019-07-18T08:15:02Z",
  }
TEST_JSON

TEST_BIGQUERY_SQL = "SELECT DISTINCT pe_build_number FROM `perf-metrics.perf_metrics.atop_metrics`"

# rubocop:disable Metrics/BlockLength
describe PerfResultsHelper do
  before do
    # TODO: test output?
    allow(subject).to receive(:puts)
  end

  # TODO: complete
  describe "#gatling2csv" do
    context "when called specifying an invalid results_dir" do
      it "raises an error with a message indicating the invalid argument" do
        expect(File).to receive(:directory?).with(TEST_METRICS_RESULTS_DIR).and_return(false)

        expect { subject.gatling2csv(TEST_METRICS_RESULTS_DIR) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_METRICS_RESULTS_DIR)}/)
      end
    end

    context "when called without specifying an output_dir" do
      it "defaults to the specified results_dir" do
        expected_csv_path = "#{TEST_METRICS_RESULTS_DIR}/#{TEST_METRICS_RESULTS_NAME}.csv"

        expect(CSV).to receive(:open).with(expected_csv_path, "wb")
        expect(subject).to receive(:csv2html).with(expected_csv_path)

        subject.gatling2csv(TEST_METRICS_RESULTS_DIR)
      end
    end

    context "when called specifying an output_dir" do
      it "uses the specified output_dir" do
        test_output_dir = "~/testing123"
        expected_csv_path = "#{test_output_dir}/#{TEST_METRICS_RESULTS_NAME}.csv"

        expect(CSV).to receive(:open).with(expected_csv_path, "wb")
        expect(subject).to receive(:csv2html).with(expected_csv_path)

        subject.gatling2csv(TEST_METRICS_RESULTS_DIR, test_output_dir)
      end
    end

    # TODO
    context "when gatling_json_stats_group_node raises an error" do
      it "does not trap the error" do
      end
    end

    # TODO
    context "when gatling_json_stats_group_node_contents raises an error" do
      it "does not trap the error" do
      end
    end

    # TODO
    context "when the 'group node' and 'contents' are returned" do
      it "creates the CSV file with the expected output path" do
      end

      it "uses the specified JSON data when building the CSV" do
      end

      it "converts the CSV file to HTML using csv2html" do
      end
    end
  end

  describe "#gatling_json_stats_group_node" do
    context "when the specified file does not exist" do
      it "raises an error" do
        expect(File).to receive(:exist?).with(TEST_STATS_PATH).and_return(false)

        expect { subject.gatling_json_stats_group_node(TEST_STATS_PATH) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_STATS_PATH)}/)
      end
    end

    context "when the JSON does not contain a group node" do
      it "raises an error" do
        expect(JSON).to receive(:parse).and_return(nil)

        expect { subject.gatling_json_stats_group_node(TEST_STATS_PATH) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_STATS_PATH)}/)
      end
    end

    context "when the JSON contains a group node" do
      it "returns the group node" do
        group_node = subject.gatling_json_stats_group_node(TEST_STATS_PATH)
        expect(group_node["type"]).to eq("GROUP")
      end
    end
  end

  describe "#gatling_json_stats_group_node_contents" do
    context "when the 'contents' element of the 'group' node is nil" do
      it "raises an error" do
        test_group_node = { "contents" => nil }

        expect { subject.gatling_json_stats_group_node_contents(test_group_node) }
          .to raise_error(RuntimeError)
      end
    end

    context "when the 'contents' element of the 'group' node is empty" do
      it "raises an error" do
        test_group_node = { "contents" => "" }
        expect { subject.gatling_json_stats_group_node_contents(test_group_node) }
          .to raise_error(RuntimeError)
      end
    end

    context "when the 'contents' element of the 'group' node has no keys" do
      it "raises an error" do
        test_group_node = { "contents" => {} }
        expect { subject.gatling_json_stats_group_node_contents(test_group_node) }
          .to raise_error(RuntimeError)
      end
    end

    context "when the 'contents' element of the 'group' node does not include the expected keys" do
      it "raises an error" do
        test_group_node = subject.gatling_json_stats_group_node(TEST_INVALID_STATS_PATH)
        expect { subject.gatling_json_stats_group_node_contents(test_group_node) }
          .to raise_error(RuntimeError, /#{TEST_INVALID_STATS_MISSING_NAME}/)
      end
    end

    context "when the 'contents' element of the 'group' node has the expected keys" do
      it "returns the expected contents" do
        group_node = subject.gatling_json_stats_group_node(TEST_STATS_PATH)
        contents = subject.gatling_json_stats_group_node_contents(group_node)
        expect(contents).to eq(group_node["contents"])
      end
    end
  end

  # TODO: complete
  describe "#csv2html_directory" do
    context "when the specified directory does not exist" do
      it "raises an error with a message indicating the invalid argument" do
        expect(File).to receive(:directory?).with(TEST_METRICS_RESULTS_DIR).and_return(false)
        expect { subject.csv2html_directory(TEST_METRICS_RESULTS_DIR) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_METRICS_RESULTS_DIR)}/)
      end
    end

    context "when no CSV files are found" do
      it "raises an error with a message indicating the issue" do
        expect(Dir).to receive(:glob).with("#{TEST_METRICS_RESULTS_DIR}/**/*.csv").and_return([])
        expect { subject.csv2html_directory(TEST_METRICS_RESULTS_DIR) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_METRICS_RESULTS_DIR)}/)
      end
    end

    context "when CSV files are found" do
      it "calls csv2html for each CSV file" do
        test_dir = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html"
        files = %W[#{test_dir}/01.csv
                   #{test_dir}/02.csv
                   #{test_dir}/invalid_columns.csv
                   #{test_dir}/invalid_one_row.csv
                   #{test_dir}/test/03.csv]

        files.each do |file|
          expect(subject).to receive(:csv2html).with(file)
        end

        subject.csv2html_directory(test_dir)
      end

      # TODO: implement
      it "suppresses errors raised by csv2html" do
      end
    end
  end

  describe "#csv2html" do
    context "when the specified file is a valid CSV file" do
      it "writes the file with the expected filename" do
        expected_html_path = "#{TEST_VALID_CSV_PATH}.html"
        expected_html = File.read(expected_html_path)
        expect(subject).to receive(:validate_csv).with(TEST_VALID_CSV_PATH).and_return(true)
        expect(File).to receive(:write).with(expected_html_path, expected_html)

        subject.csv2html(TEST_VALID_CSV_PATH)
      end
    end
  end

  # TODO: complete
  describe "#average_csv" do
    context "when the specified file does not contain more than one row" do
      it "raises an error" do
        expect { subject.average_csv(TEST_VALID_CSV_HEADINGS_PATH) }
          .to raise_error(RuntimeError)
      end
    end

    # TODO
    context "when skip_first_column is specified" do
      it "skips the first column" do
      end
    end

    # TODO
    context "when a non-integer value is encountered" do
      it "raises an error" do
      end
    end

    # TODO
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  describe "#validate_csv" do
    context "when the specified file does not exist" do
      it "raises an error" do
        expect(File).to receive(:exist?).with(TEST_VALID_CSV_PATH).and_return(false)

        expect { subject.validate_csv(TEST_VALID_CSV_PATH) }
          .to raise_error(RuntimeError, /File not found: #{Regexp.escape(TEST_VALID_CSV_PATH)}/)
      end
    end

    context "when the specified file is not a CSV file" do
      it "raises an error" do
        file = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/not_a_csv.txt"

        expect { subject.validate_csv(file) }
          .to raise_error(RuntimeError, /Not a CSV file: #{Regexp.escape(file)}/)
      end
    end

    context "when the specified file only contains one row" do
      it "raises an error" do
        invalid_csv = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/invalid_one_row.csv"

        expect { subject.validate_csv(invalid_csv) }
          .to raise_error(RuntimeError, /#{Regexp.escape(invalid_csv)}/)
      end
    end

    context "when the specified file contains a row with an invalid number of columns" do
      it "raises an error" do
        invalid_csv = "#{PERF_RESULTS_FIXTURES_DIR}/csv2html/invalid_columns.csv"

        expect { subject.validate_csv(invalid_csv) }
          .to raise_error(RuntimeError, /#{Regexp.escape(invalid_csv)}/)
      end
    end

    context "when the specified file is a valid CSV file" do
      it "returns true" do
        expect(subject.validate_csv(TEST_VALID_CSV_PATH)).to eq(true)
      end
    end
  end

  # TODO: complete
  describe "#extract_table_from_csv2html_output" do
    context "when the specified file does not exist" do
      it "raises an error" do
        expect(File).to receive(:exist?).with(TEST_VALID_HTML_PATH).and_return(false)

        expect { subject.extract_table_from_csv2html_output(TEST_VALID_HTML_PATH) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_VALID_HTML_PATH)}/)
      end
    end

    context "when the html does not contain a table" do
      it "raises an error" do
        html_no_table = PerfResultsHelper::CSV_HTML_START + PerfResultsHelper::CSV_HTML_END
        expect(File).to receive(:read).with(TEST_VALID_HTML_PATH).and_return(html_no_table)

        expect { subject.extract_table_from_csv2html_output(TEST_VALID_HTML_PATH) }
          .to raise_error(RuntimeError, /#{Regexp.escape(TEST_VALID_HTML_PATH)}/)
      end
    end

    context "when the html contains a table" do
      it "returns the table string" do
        expect(subject.extract_table_from_csv2html_output(TEST_VALID_HTML_PATH)).to eq(TEST_HTML_TABLE)
      end
    end
  end

  # TODO
  describe "#split_atop_csv_results" do
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  # TODO
  describe "#compare_atop_csv_results" do
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  # TODO
  describe "#compare_atop_summary" do
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  # TODO
  describe "#compare_atop_detail" do
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  # TODO
  describe "#percent_diff" do
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  # TODO
  describe "#percent_diff_string" do
    context "when called" do
      it "does the expected thing" do
      end
    end
  end

  describe "#extract_puppet_metrics_collector_data" do
    context "when the specified file does not exist" do
      it "raises an error" do
        test_path = "/not/a/valid/path"
        expect { subject.extract_puppet_metrics_collector_data(test_path) }
          .to raise_error(RuntimeError, /File not found: #{Regexp.escape(test_path)}/)
      end
    end

    context "when the specified path is neither a tar file or directory" do
      it "raises an error with a message indicating the invalid argument" do
        test_path = "#{PERF_RESULTS_FIXTURES_DIR}/not_a_real_tar_file.txt.tar.gz"
        expect { subject.extract_puppet_metrics_collector_data(test_path) }
          .to raise_error(RuntimeError, /#{Regexp.escape(test_path)}/)
      end
    end

    context "when the specified path is a tar file" do
      it "extracts the tar file and uses the extracted puppet_metrics_collector directory" do
        tar_file = "puppet_metrics_collector.tar.gz"
        tar_path = "#{PERF_RESULTS_FIXTURES_DIR}/#{tar_file}"
        puppet_metrics_dir_name = PerfResultsHelper::PUPPET_METRICS_COLLECTOR_DIR_NAME
        puppet_metrics_dir = "#{PERF_RESULTS_FIXTURES_DIR}/#{puppet_metrics_dir_name}"

        expect(subject).to receive(:extract_tgz).with(tar_path)
        expect(subject).to receive(:extract_puppetserver_metrics).with(puppet_metrics_dir)
        subject.extract_puppet_metrics_collector_data(tar_path)
      end
    end

    context "when the specified path is a directory" do
      it "uses the specified directory" do
        expect(subject).to receive(:extract_puppetserver_metrics).with(PUPPET_METRICS_FIXTURES_DIR)
        subject.extract_puppet_metrics_collector_data(PUPPET_METRICS_FIXTURES_DIR)
      end
    end
  end

  # TODO: implement
  describe "#extract_tarball" do
    context "when ..." do
      it "does ..." do
        # expect(Archive::Tar::Minitar).to receive(:unpack).with(tar_path, PERF_RESULTS_FIXTURES_DIR)
      end
    end
  end

  # TODO: complete
  describe "#extract_puppetserver_metrics" do
    puppetserver_dir = "#{PUPPET_METRICS_FIXTURES_DIR}/puppetserver"

    context "when the puppetserver directory does not exist" do
      it "raises an error with a message indicating the invalid argument" do
        expect(File).to receive(:directory?).with(puppetserver_dir).and_return(false)
        expect { subject.extract_puppetserver_metrics(PUPPET_METRICS_FIXTURES_DIR) }
          .to raise_error(RuntimeError, /#{Regexp.escape(puppetserver_dir)}/)
      end
    end

    context "when the puppetserver directory contains no JSON files" do
      it "raises an error with a message indicating the invalid argument" do
        expect(Dir).to receive(:glob).and_return(nil)
        expect { subject.extract_puppetserver_metrics(PUPPET_METRICS_FIXTURES_DIR) }
          .to raise_error(RuntimeError, /#{Regexp.escape(puppetserver_dir)}/)
      end
    end

    # TODO
    context "when the puppetserver directory contains JSON files" do
      # TODO
      it "creates the expected CSV file" do
      end

      # TODO
      it "calls process_puppetserver_json for each file" do
      end

      # TODO
      it "adds the metrics from each file to the CSV file" do
      end

      # TODO
      it "calls average_csv specifying the created CSV file" do
      end

      # TODO
      it "calls csv2html specifying the created CSV file" do
      end
    end
  end

  # TODO: complete
  describe "#extract_puppetserver_metrics_from_json" do
    puppetserver_dir = "#{PUPPET_METRICS_FIXTURES_DIR}/puppetserver"
    puppetserver_json = "#{puppetserver_dir}/ip-10-227-1-138.amz-dev.puppet.net/20190718T081502Z.json"

    context "when the specified file does not exist" do
      it "raises an error" do
        expect(File).to receive(:exist?).with(puppetserver_json).and_return(false)

        expect { subject.extract_puppetserver_metrics_from_json(puppetserver_json) }
          .to raise_error(RuntimeError, /#{Regexp.escape(puppetserver_json)}/)
      end
    end

    context "when the specified file is not valid JSON" do
      it "raises an error" do
        invalid_json = "not JSON!"
        expect(File).to receive(:read).with(puppetserver_json).and_return(invalid_json)

        expect { subject.extract_puppetserver_metrics_from_json(puppetserver_json) }
          .to raise_error(JSON::ParserError, /#{invalid_json}/)
      end
    end

    context "when the specified file does not contain catalog metrics" do
      it "outputs a helpful message" do
        json = "#{PERF_RESULTS_FIXTURES_DIR}/misc/pmc_error.json"

        expect(subject).to receive(:puts).with(/ignoring/)

        subject.extract_puppetserver_metrics_from_json(json)
      end
    end

    # TODO
    context "when the specified file contains catalog metrics" do
      it "returns the metrics" do
      end
    end
  end

  describe "#query_bigquery" do
    let(:logger) { double }
    let(:test_google_bigquery) { Class.new }
    let(:test_bigquery_instance) { Class.new }
    test_data = [{ "field" => "value" }]

    before do
      allow(subject).to receive(:logger).and_return(logger)
      stub_const("Google::Cloud::Bigquery", test_google_bigquery)
    end

    context "when the GOOGLE_APPLICATION_CREDENTIALS environment variable is nil" do
      it "raises an error" do
        ENV["GOOGLE_APPLICATION_CREDENTIALS"] = nil
        expect { subject.query_bigquery(TEST_BIGQUERY_SQL) }
          .to raise_error(/GOOGLE_APPLICATION_CREDENTIALS/)
      end
    end

    context "when the GOOGLE_APPLICATION_CREDENTIALS environment variable is empty" do
      it "raises an error" do
        ENV["GOOGLE_APPLICATION_CREDENTIALS"] = ""
        expect { subject.query_bigquery(TEST_BIGQUERY_SQL) }
          .to raise_error(/GOOGLE_APPLICATION_CREDENTIALS/)
      end
    end

    context "when the GOOGLE_APPLICATION_CREDENTIALS environment variable is set" do
      it "queries BigQuery with the specified sql and returns the data" do
        ENV["GOOGLE_APPLICATION_CREDENTIALS"] = "test"
        expect(test_google_bigquery).to receive(:new).and_return(test_bigquery_instance)
        expect(test_bigquery_instance).to receive(:query).and_return(test_data)

        expect(subject.query_bigquery(TEST_BIGQUERY_SQL)).to eq(test_data)
      end
    end

    context "when the query execution returns empty data" do
      it "logs the error and returns the data" do
        ENV["GOOGLE_APPLICATION_CREDENTIALS"] = "test"
        empty_data = []
        expect(test_google_bigquery).to receive(:new).and_return(test_bigquery_instance)
        expect(test_bigquery_instance).to receive(:query).and_return(empty_data)
        expect(logger).to receive(:error)

        expect(subject.query_bigquery(TEST_BIGQUERY_SQL)).to eq(empty_data)
      end
    end
  end

  describe "#baseline_pe_versions" do
    context "when the query execution returns empty data" do
      it "raises an error" do
        expect(subject).to receive(:query_bigquery).and_return([])
        expect { subject.baseline_pe_versions }
          .to raise_error(/Error/)
      end
    end

    context "when the query execution returns non-empty data" do
      it "returns an array of the baseline versions" do
        test_result = [pe_build_number: "2142.2.1"]
        test_expected_versions = ["2142.2.1"]

        expect(subject).to receive(:query_bigquery).and_return(test_result)
        expect(subject.baseline_pe_versions).to eq(test_expected_versions)
      end
    end
  end

  describe "#verify_baseline_pe_version" do
    test_baseline_versions = ["2142.2.1"]

    context "when the specified version is found" do
      it "returns true" do
        test_version = "2142.2.1"

        expect(subject).to receive(:baseline_pe_versions).and_return(test_baseline_versions)
        expect(subject.verify_baseline_pe_version(test_version)).to eq(true)
      end
    end

    context "when the specified version is not found" do
      it "raises an error" do
        test_version = "1942.2.1"
        expect(subject).to receive(:baseline_pe_versions).and_return(test_baseline_versions)
        expect { subject.verify_baseline_pe_version(test_version) }
          .to raise_error(/#{test_version}/)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
