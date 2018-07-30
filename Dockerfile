FROM ruby:2.2.3-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
	build-essential && \
	apt-get -y install libcurl3 libcurl3-gnutls libcurl4-openssl-dev && \
	rm -rf /var/lib/apt/lists/*
RUN mkdir -p /app
COPY Gemfile /app/
WORKDIR /app
RUN bundle install
COPY . /app
ENV PORT 4012
ENV SEC_FLAG false
ENV MAIN_DB tng-rep
ENV MAIN_DB_HOST mongo
ENV DEFAULT_PAGE_NUMBER 1
ENV DEFAULT_PAGE_SIZE 100
EXPOSE 4012
CMD ["rake", "start"]
