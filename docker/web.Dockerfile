FROM ruby:alpine

RUN apk update && apk add build-base

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler --no-document
RUN bundle install --no-binstubs --jobs $(nproc) --retry 3

COPY . .

# Don't run as `root`
RUN addgroup -g 22430 -S app \
    && adduser -u 22430 -S app -G app
RUN chown -R app:app /app/*
USER app

EXPOSE 5000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]