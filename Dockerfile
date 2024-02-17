# spyserver/Dockerfile
FROM debian:bookworm-slim AS build

WORKDIR /src

# Install dependencies
RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential \
  cmake \
  git \
  curl \
  libusb-1.0-0-dev \
  ca-certificates \
  pkg-config \
  #SDR++ dependencies
  libfftw3-dev \
  libglfw3-dev \
  libvolk2-dev \
  libzstd-dev \
  librtaudio-dev

# Airspy Mini Driver
WORKDIR /src/
RUN git clone https://github.com/airspy/airspyone_host.git
WORKDIR /src/airspyone_host
RUN mkdir build && cd build && cmake ../ -DINSTALL_UDEV_RULES=ON && make -j`nproc` && make install -j`nproc` && ldconfig

# Airspy HF+ Driver
WORKDIR /src/
RUN git clone https://github.com/airspy/airspyhf.git
WORKDIR /src/airspyhf
RUN mkdir build && cd build && cmake ../ -DINSTALL_UDEV_RULES=ON && make -j`nproc` && make install -j`nproc` && ldconfig

# SDR++
WORKDIR /src/
RUN git clone https://github.com/AlexandreRouma/SDRPlusPlus.git
WORKDIR /src/SDRPlusPlus
RUN mkdir build && cd build && cmake ../ \
  -DOPT_BUILD_AIRSPYHF_SOURCE=ON -DOPT_BUILD_HACKRF_SOURCE=OFF \
  -DOPT_BUILD_HERMES_SOURCE=OFF -DOPT_BUILD_PLUTOSDR_SOURCE=OFF \
  -DOPT_BUILD_RFSPACE_SOURCE=OFF -DOPT_BUILD_RTL_SDR_SOURCE=OFF \
  -DOPT_BUILD_SOAPY_SOURCE=OFF -DOPT_BUILD_SPECTRAN_SOURCE=OFF && make -j`nproc` && make install -j`nproc` && ldconfig
RUN which sdrpp

FROM debian:bookworm-slim AS runtime

# Airspy and SDR++ libs/binaries
COPY --from=build /usr/local /usr/local
RUN ldconfig

# SDR++
COPY --from=build /usr/bin/sdrpp /usr/bin/sdrpp
COPY --from=build /usr/share/sdrpp /usr/share/sdrpp
COPY --from=build /usr/lib/libsdrpp_core.so /usr/lib/libsdrpp_core.so
COPY --from=build /usr/lib/sdrpp /usr/lib/sdrpp
RUN ldconfig

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  curl \
  libfftw3-bin \
  libglfw3 \
  libvolk2-bin \
  libzstd1 \
  librtaudio6 \
  libopengl0 \
  libusb-1.0-0

WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh

EXPOSE 5259

ENTRYPOINT ["sh", "entrypoint.sh"]
CMD ["sdrpp", "--server"]