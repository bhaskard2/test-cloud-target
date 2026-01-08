FROM mcr.microsoft.com/dotnet/sdk:8.0

ARG POWERSHELL_VERSION=7.5.4

# Install the requested PowerShell version from the official linux-x64 tar.gz.
RUN set -e; \
    apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    curl -L -o /tmp/powershell.tar.gz \
        "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-x64.tar.gz" && \
    mkdir -p /opt/microsoft/powershell/7 && \
    tar zxf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7 && \
    chmod +x /opt/microsoft/powershell/7/pwsh && \
    ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh && \
    rm /tmp/powershell.tar.gz

RUN pwsh -NoLogo -NonInteractive -Command \
    "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
     Install-Module -Name Pester -Force -Scope AllUsers"

WORKDIR /sizing_tests

#   /sizing_tests/*.ps1                (all cloud scripts)
#   /sizing_tests/tests/**              (all Pester tests)
COPY cloud/ /sizing_tests/
COPY tests/ /sizing_tests/tests

CMD ["pwsh", "-NoLogo", "-NonInteractive", "-File", "./tests/Invoke-PesterWithCoverage.ps1"]
