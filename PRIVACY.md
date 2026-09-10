# HWControl 2.0 Privacy Policy

**Effective date:** 2026-09-10

HWControl 2.0 is an open-source desktop application for hardware monitoring and control. This policy describes the privacy behavior of the application and its release website.

## 1. Data collected by the application

HWControl uses a **local-first telemetry model**.

The application does not intentionally collect or transmit unnecessary telemetry, usage analytics, advertising identifiers, or behavioral tracking data.

Hardware and system information used by HWControl may include CPU/GPU utilization, temperatures, memory usage, disk usage, fan state, driver information, uptime, and related hardware diagnostics. This information is collected by the local application/bridge so that it can display and control the user's own system.

This monitoring data remains on the user's computer unless the user explicitly exports, copies, shares, or otherwise sends it elsewhere.

## 2. Local bridge communication

The HWControl dashboard communicates with the local bridge service over loopback communication. The bridge is designed to bind to `127.0.0.1` by default and uses authenticated requests between application components.

The local bridge is not intended to be a remote telemetry collection service.

## 3. Updates and release information

HWControl may check for available releases using HTTPS requests to the project's allowlisted GitHub release infrastructure. This request is used for release/update information and is not an application telemetry upload channel.

As with any HTTPS connection, the network provider and the contacted third-party service may process connection information such as an IP address, request metadata, or user-agent information according to their own policies. HWControl does not control those third-party practices.

The application does not automatically install or execute updates.

## 4. Explicit exports and sharing

If a user explicitly exports diagnostics, monitoring information, logs, or other application data, the resulting data is under the user's control. The user is responsible for deciding where that exported information is stored or shared.

HWControl does not intentionally upload such information to project infrastructure without an explicit user action.

## 5. Website

The official project website is hosted through GitHub Pages. GitHub may process technical request information required to provide and protect the website. Those practices are governed by GitHub's own policies.

The HWControl website does not intentionally use advertising identifiers or behavioral tracking as part of the project application.

## 6. Third-party software and services

HWControl can interact with the operating system, hardware drivers, GitHub release infrastructure, and other third-party software or services. Those components may have their own privacy policies and data practices.

This policy does not claim that the operating system, GPU drivers, GitHub, or other third-party software on a user's computer collect no data.

## 7. Security and transparency

The project's security documentation provides additional technical information about telemetry, release integrity, update behavior, and security controls.

See the repository's `SECURITY.md` and code-signing documentation for the current implementation and release-security details.

## 8. Changes to this policy

This policy may be updated when HWControl's data handling or privacy-relevant behavior changes. Material changes will be documented in the project repository and release information.

## 9. Contact

Privacy and security questions can be raised through the project's official GitHub repository and its security-reporting process.

Project repository: https://github.com/lordkeremello45/HWcontrol2.0

---

HWControl 2.0 is distributed under the GNU General Public License v3.0.
