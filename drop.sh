#!/bin/sh
RAILS_ENV=bbs rake db:drop
RAILS_ENV=bbs rake db:create
RAILS_ENV=bbs rake db:migrate
