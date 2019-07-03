FROM amazonlinux:2

ENV ruby_ver="2.4"
USER root

RUN yum -y update
RUN yum -y install epel-release git make autoconf \
curl wget gcc-c++ glibc-headers openssl-devel \
readline libyaml-devel readline-devel \
zlib zlib-devel sqlite-devel bzip2 rpm-build ruby-devel postgresql-devel

RUN amazon-linux-extras install ruby${ruby_ver}
RUN gem update && gem install bundler

RUN mkdir ~/.ssh
WORKDIR /root/app
COPY . ./
RUN bundle install --path vendor/bundle
