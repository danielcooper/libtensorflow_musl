# libtensorflow_musl

Provides a libtensorflow built with musl - making it easier to deploy a model using the C/Golang
bindings on an alpine docker.

## Usage

```
FROM danielcooper/libtensorflow_musl:1.11.0 as libtensorflow
...
COPY --from=libtensorflow /tensorflow /usr/lib
RUN ldconfig /usr/lib
```

Based on: https://github.com/better/alpine-tensorflow
