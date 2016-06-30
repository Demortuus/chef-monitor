require 'sensu/transport/base'
require 'aws-sdk'

module Sensu
  module Transport
    class SNSSQS < Sensu::Transport::Base
      attr_accessor :logger

      STRING_STR     = 'String'.freeze
      KEEPALIVES_STR = 'keepalives'.freeze
      PIPE_STR       = 'pipe'.freeze
      TYPE_STR       = 'type'.freeze

      def initialize
        @connected = false
        @subscribing = false

        # as of sensu 0.23.0 we need to call succeed when we have
        # successfully connected to SQS.
        #
        # we already have our own logic to maintain the connection to
        # SQS, so we can always say we're connected.
        #
        # See:
        # https://github.com/sensu/sensu/blob/cdc25b29169ef2dcd2e056416eab0e83dbe000bb/CHANGELOG.md#0230---2016-04-04
        succeed
      end

      def connected?
        @connected
      end

      def connect(settings)
        @settings = settings
        @connected = true
        @results_callback = proc {}
        @keepalives_callback = proc {}
        @sqs = Aws::SQS::Client.new(region: @settings[:region])
        @sns = Aws::SNS::Client.new(region: @settings[:region])
      end

      def statsd_incr(stat)
      end

      def statsd_time(stat)
      end

      # subscribe will begin "subscribing" to the consuming sqs queue.
      #
      # What this really means is that we will start polling for
      # messages from the SQS queue, and, depending on the message
      # type, it will call the appropriate callback.
      #
      # This assumes that the SQS Queue is consuming "Raw" messages
      # from SNS.
      #
      # "subscribing" means that the "callback" parameter will be
      # called when there is a message for you to consume.
      #
      # "funnel" and "type" parameters are completely ignored.
      def subscribe(type, pipe, funnel=nil, _options={}, &callback)
        logger.info("subscribing to type=#{type}, pipe=#{pipe}, funnel=#{funnel}")

        if pipe == KEEPALIVES_STR
          @keepalives_callback = callback
        else
          @results_callback = callback
        end

        unless @subscribing
          do_all_the_time do
            EM::Iterator.new(receive_messages, 10).each do |msg, iter|
              statsd_time("sqs.#{@settings[:consuming_sqs_queue_url]}.process_timing") do
                if msg.message_attributes[PIPE_STR].string_value == KEEPALIVES_STR
                  @keepalives_callback.call(msg, msg.body)
                else
                  @results_callback.call(msg, msg.body)
                end
              end
              iter.next
            end
          end
          @subscribing = true
        end
      end

      # acknowledge will delete the given message from the SQS queue.
      def acknowledge(info, &callback)
        EM.defer do
          @sqs.delete_message(
            queue_url: @settings[:consuming_sqs_queue_url],
            receipt_handle: info.receipt_handle
          )
          statsd_incr("sqs.#{@settings[:consuming_sqs_queue_url]}.message.deleted")
          yield(info) if callback
        end
      end

      # publish publishes a message to the SNS topic.
      #
      # The type, pipe, and options are transformed into SNS message
      # attributes and included with the message.
      def publish(type, pipe, message, options={}, &callback)
        attributes = {
          TYPE_STR => str_attr(type),
          PIPE_STR => str_attr(pipe)
        }
        options.each do |k, v|
          attributes[k.to_s] = str_attr(v.to_s)
        end
        EM.defer { send_message(message, attributes, &callback) }
      end

      private

      def str_attr(str)
        { data_type: STRING_STR, string_value: str }
      end

      def do_all_the_time(&blk)
        callback = proc do
          do_all_the_time(&blk)
        end
        EM.defer(blk, callback)
      end

      def send_message(msg, attributes, &callback)
        resp = @sns.publish(
          target_arn: @settings[:publishing_sns_topic_arn],
          message: msg,
          message_attributes: attributes
        )
        statsd_incr("sns.#{@settings[:publishing_sns_topic_arn]}.message.published")
        yield({ response: resp }) if callback
      end

      PIPE_ARR = [PIPE_STR].freeze

      # receive_messages returns an array of SQS messages
      # for the consuming queue
      def receive_messages
        resp = @sqs.receive_message(
          message_attribute_names: PIPE_ARR,
          queue_url: @settings[:consuming_sqs_queue_url],
          wait_time_seconds: @settings[:wait_time_seconds],
          max_number_of_messages: @settings[:max_number_of_messages]
        )
        resp.messages
      rescue Aws::SQS::Errors::ServiceError => e
        logger.info(e)
      end
    end
  end
end
