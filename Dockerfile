FROM alpine:latest

# Based on https://github.com/tatsushid/docker-alpine-py3-tensorflow-jupyter/blob/master/Dockerfile
# Changes:
# - Bumping versions of Bazel and Tensorflow
# - Add -Xmx to the Java params when building Bazel
# - Disable TF_GENERATE_BACKTRACE and TF_GENERATE_STACKTRACE

ENV JAVA_HOME /usr/lib/jvm/java-1.8-openjdk


RUN apk add --no-cache --virtual=.build-deps \
        bash \
        cmake \
        curl \
        freetype-dev \
        g++ \
        git \
        libjpeg-turbo-dev \
        libpng-dev \
        linux-headers \
        make \
        musl-dev \
        openblas-dev \
        openjdk8 \
        patch \
        perl \
        python3 \
        python3-dev \
        py-numpy-dev \
        rsync \
        sed \
        swig \
        zip \
    && cd /tmp \
    && pip3 install --no-cache-dir wheel \
&& $(cd /usr/bin && ln -s python3 python)

ENV BAZEL_VERSION 0.15.2

# Bazel download
RUN curl -SLO https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VERSION}/bazel-${BAZEL_VERSION}-dist.zip \
    && mkdir bazel-${BAZEL_VERSION} \
&& unzip -qd bazel-${BAZEL_VERSION} bazel-${BAZEL_VERSION}-dist.zip

RUN cd bazel-${BAZEL_VERSION} \
    && sed -i -e 's/-classpath/-J-Xmx8192m -J-Xms128m -classpath/g' scripts/bootstrap/compile.sh \
    && bash compile.sh \
&& cp -p output/bazel /usr/bin/

# Download Tensorflow
ENV TENSORFLOW_VERSION 1.11.0

RUN cd /tmp \
    && curl -SL https://github.com/tensorflow/tensorflow/archive/v${TENSORFLOW_VERSION}.tar.gz \
      | tar xzf -

ENV LOCAL_RESOURCES 2048,0.5,1.0
# Build Tensorflow
RUN cd /tmp/tensorflow-${TENSORFLOW_VERSION} \
  && : musl-libc does not have "secure_getenv" function \
  && sed -i -e '/JEMALLOC_HAVE_SECURE_GETENV/d' third_party/jemalloc.BUILD \
  && sed -i -e '/define TF_GENERATE_BACKTRACE/d' tensorflow/core/platform/default/stacktrace.h \
  && sed -i -e '/define TF_GENERATE_STACKTRACE/d' tensorflow/core/platform/stacktrace_handler.cc \
  &&  CC_OPT_FLAGS="-march=native" \
      TF_NEED_JEMALLOC=1 \
      TF_NEED_GCP=0 \
      TF_NEED_HDFS=0 \
      TF_NEED_S3=0 \
      TF_ENABLE_XLA=0 \
      TF_NEED_GDR=0 \
      TF_NEED_VERBS=0 \
      TF_NEED_OPENCL=0 \
      TF_NEED_CUDA=0 \
      TF_NEED_MPI=0 \
      bash configure
RUN cd /tmp/tensorflow-${TENSORFLOW_VERSION} \
    && bazel build -c opt --local_resources ${LOCAL_RESOURCES} //tensorflow:libtensorflow.so

FROM scratch
  COPY --from=0 /tmp/tensorflow-1.11.0/bazel-bin/tensorflow/libtensorflow.so /tensorflow/libtensorflow.so
  COPY --from=0 /tmp/tensorflow-1.11.0/bazel-bin/tensorflow/libtensorflow_framework.so /tensorflow/libtensorflow_framework.so
