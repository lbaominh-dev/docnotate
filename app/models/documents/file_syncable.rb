module Documents
  module FileSyncable
    extend ActiveSupport::Concern

    class_methods do
      def normalize_file_path(path)
        return path if path.blank?

        cleaned = path.to_s.strip
        return cleaned unless cleaned.start_with?(%r{file:}i)

        cleaned = cleaned.sub(%r{\Afile://localhost(?=/|\z)}i, "")
        cleaned = cleaned.sub(%r{\Afile://}i, "")
        cleaned = cleaned.sub(%r{\Afile:}i, "")
        cleaned = cleaned.split(/[?#]/, 2).first

        begin
          cleaned = URI.decode_uri_component(cleaned)
        rescue ArgumentError
        end

        if cleaned.match?(%r{\A/[a-zA-Z]:/})
          cleaned.sub(%r{\A/}, "")
        elsif !cleaned.start_with?("/") && !cleaned.match?(%r{\A[a-zA-Z]:})
          "/#{cleaned}"
        else
          cleaned
        end
      end

      def open(file_path, content: nil, user: nil)
        file_path = normalize_file_path(file_path)

        scope = user ? user.documents : self

        # If content is explicitly provided (e.g. from browser file upload or agent sync)
        if content.present?
          file_type = file_type_from_path(file_path)
          document = scope.find_or_initialize_by(file_path: file_path)
          document.user = user if user && document.user_id.nil?

          need_parse = document.new_record? || document.content != content

          document.assign_attributes(
            content: content,
            file_type: file_type,
            last_opened_at: Time.current
          )

          if document.save && need_parse
            metadata = AstParseable::ParseMetadata.new(size: content.bytesize, last_modified_at: Time.current)
            document.parse_ast_and_save!(metadata: metadata)
          end

          return document
        end

        # Absolute file path check for local disk
        expanded_path = file_path.start_with?("/") || file_path.match?(/\A[a-zA-Z]:/) ? file_path : File.expand_path(file_path)
        file_exists = File.exist?(expanded_path)

        if file_exists
          expanded_path = File.realpath(expanded_path)
          disk_content = File.read(expanded_path)
          file_type = file_type_from_path(expanded_path)
          file_stats = File.stat(expanded_path)
          file_mtime = file_stats.mtime.change(nsec: file_stats.mtime.usec * 1000)

          document = scope.find_or_initialize_by(file_path: expanded_path)
          document.user = user if user && document.user_id.nil?
          current_version = document.current_version
          need_parse = document.new_record? ||
                       (current_version&.last_modified_at.present? && current_version.last_modified_at < file_mtime) ||
                       (current_version&.size.present? && current_version.size != file_stats.size)

          document.assign_attributes(
            content: disk_content,
            file_type: file_type,
            last_opened_at: Time.current
          )

          if document.save && need_parse
            metadata = AstParseable::ParseMetadata.new(size: file_stats.size, last_modified_at: file_mtime)
            document.parse_ast_and_save!(metadata: metadata)
          end

          return document
        end

        # If not found on server disk, look in database for already synced documents for this user
        existing = scope.find_by(file_path: file_path) ||
                   scope.find_by(file_path: expanded_path) ||
                   scope.find_by(name: file_path) ||
                   scope.find_by(name: File.basename(file_path))

        if existing
          existing.touch_last_opened!
          return existing
        end

        raise ArgumentError, "File does not exist"
      end
    end
  end
end
