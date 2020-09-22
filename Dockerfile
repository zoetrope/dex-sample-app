FROM golang:1.15.2 AS build

WORKDIR /work

COPY src /work/
COPY go.mod /work
COPY go.sum /work

RUN CGO_ENABLED=0 go install .

FROM gcr.io/distroless/base
COPY --from=build /go/bin /

USER 10000:10000
ENTRYPOINT ["/dex-sample-app"]
