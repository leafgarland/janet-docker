FROM alpine:3 as alpine-dev
RUN apk add --no-cache gcc musl-dev make git bash

FROM alpine-dev as build
WORKDIR /build
ARG COMMIT=HEAD
RUN git clone https://github.com/janet-lang/janet.git .
RUN git checkout $COMMIT
# Use COPY instead of git clone to work with a local janet install
# COPY . .
RUN make PREFIX=/app -j
RUN make test
RUN make PREFIX=/app install

FROM alpine-dev as dev
COPY --from=build /app /app
ENV PATH="/app/bin:$PATH"
WORKDIR /app
CMD ["bash"] 

FROM alpine as core
COPY --from=build /app/ /app/
ENV PATH="/app/bin:$PATH"
WORKDIR /app
CMD ["janet"] 
