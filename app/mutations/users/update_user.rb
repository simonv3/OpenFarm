module Users
  class UpdateUser < Mutations::Command

    required do
      string :id
      model :current_user, class: 'User'
      hash :attributes do
        optional do
          string :display_name
          string :mailing_list
          string :help_list
          string :is_private
        end
      end
    end
    optional do
      hash :user_setting do
        optional do
          string :location
          string :years_experience
          string :units
          string :favorite_crop
        end
      end
      string :featured_image
    end

    def validate
      validate_user
      validate_favorite_crop
      validate_image
    end

    def execute
      @user = User.find(id)
      set_user_setting
      set_image
      @user.update_attributes(attributes)
      @user.save
      @user
    end

    protected

    def set_user_setting
      if user_setting
        set_favorite_crop
        @user.user_setting.update_attributes(user_setting)
        @user.user_setting.save
      end
    end

    def set_favorite_crop
      if @favorite_crop
        @user.user_setting.favorite_crops = [@favorite_crop]
      end
    end

    def validate_favorite_crop
      if user_setting && user_setting[:favorite_crop]
        # remove favorite crop from hash, causin' problems
        @favorite_crop = [Crop.find(user_setting.delete('favorite_crop'))]
      end
    rescue Mongoid::Errors::DocumentNotFound
      msg = "Could not find a crop with id #{user_setting[:favorite_crop]}"
      add_error user_setting[:favorite_crop], :crop_not_found, msg
    end

    def validate_user
      # TODO update this to use the Policy
      if current_user.id.to_s != id.to_s
        msg = 'You can only update your own profile'
        raise OpenfarmErrors::NotAuthorized, msg
      end
    end

    def validate_image
      if featured_image
        outcome = Pictures::CreatePicture.validate(url: featured_image)
        unless outcome.success?
          add_error :images,
                    :bad_format,
                    outcome.errors.message_list.to_sentence
        end
      end
    end

    def set_image
      existing_url = nil
      if @user.user_setting.picture
        existing_url = @user.user_setting.picture.attachment.url
      end
      if featured_image && featured_image != existing_url
        UserSetting.from_url(featured_image, @user.user_setting)
      end
      unless featured_image || @user.user_setting.picture == nil
        @user.user_setting.picture.remove
      end
    end
  end
end
