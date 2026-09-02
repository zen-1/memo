# Custom dify-sandbox image with tshark (Wireshark CLI) installed.
#
# tshark is used from workflow Code nodes to parse pcap files (richer
# protocol dissection than hand-rolling a parser). Running any external
# command from a Code node also requires relaxing the sandbox's seccomp
# process-spawn restrictions via the ALLOWED_SYSCALLS env var on the
# `sandbox` service (see docker/docker-compose.override.yaml) -- installing
# tshark here is necessary but not sufficient on its own.
FROM langgenius/dify-sandbox:0.2.15

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends tshark \
    && rm -rf /var/lib/apt/lists/*
