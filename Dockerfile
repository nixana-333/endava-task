FROM nginx

WORKDIR /usr/share/nginx/html/
RUN curl -O https://hereismynginxfile.s3.amazonaws.com/index.html