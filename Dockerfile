FROM alpine:3.7
LABEL maintainer="Joelle Gilley gilley.joelle@gmail.com"

# use rbenv understandable version
ARG RUBY_VERSION
ENV RUBY_VERSION=${RUBY_VERSION:-2.3.2}

# Set the timezone
# ENV TIMEZONE=America/New_York
ENV TIMEZONE=UTC

# Load ash profile on launch
ENV ENV=/etc/profile

ENV PATH="/root/.rbenv/bin:$PATH"
ENV RUBY_CONFIGURE_OPTS=--disable-install-doc

# Add the www-data user and group, fail on error
RUN addgroup -g 82 -S www-data && \
	adduser -u 82 -D -S -G www-data www-data

# Setup ash profile prompt and my old man alias
# Create work directory
RUN mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
    echo alias dir=\'ls -alh --color\' >> /etc/profile && \
    echo 'source ~/.profile' >> /etc/profile && \
    mkdir -p /app /run/nginx

# Install the required services dumb-init.  Also install and fix timezones / ca-certificates
# Install nginx
RUN apk --update --no-cache add dumb-init tzdata ca-certificates nginx bash openssl && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apk del tzdata && \
    update-ca-certificates && \
    rm -rf /etc/nginx/conf.d/default.conf && \
	mkdir -p /run/nginx && \
	chown -R nginx:www-data /run/nginx && \
	chown -R :www-data /app && \
	chmod -R g+rw /app

# install needed libs to build ruby and gems mark as build-deps so can be
# easily removed at a later time
RUN apk add --no-cache --update --virtual build-deps  \
	git curl build-base linux-headers \
	readline-dev openssl-dev zlib-dev

# USER app
WORKDIR /app

# install rbenv
RUN git clone --depth 1 https://github.com/rbenv/rbenv.git ~/.rbenv && \
	cd ~/.rbenv && \
	src/configure && \
	make -C src && \
	echo 'export RUBY_CONFIGURE_OPTS=--disable-install-doc' >> ~/.profile && \
	echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile && \
	echo 'eval "$(rbenv init -)"' >> ~/.profile && \
	echo 'gem: --no-document' >> ~/.gemrc

# install ruby
RUN eval "$(rbenv init -)" && \
	git clone --depth 1 https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build  && \
	rbenv install ${RUBY_VERSION} && \
	rbenv global ${RUBY_VERSION}

# install puma and bundler
RUN eval "$(rbenv init -)" && \
	gem install bundler puma

# Copy over the code Gemfile and run the install
COPY ./code/Gemfile* ./
RUN eval "$(rbenv init -)" && \
	bundle install

# remove the build system
RUN apk del build-deps

COPY ./code/ ./

#
#
# RUBY_CONFIGURE_OPTS=--disable-install-doc rbenv install 2.3.2

