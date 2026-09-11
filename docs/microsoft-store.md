# Microsoft Store release setup

HWControl uses Flutter's `msix` package to create the Store MSIX and the Microsoft Store Developer CLI (`msstore`) for CI/CD publication.

Microsoft Store currently requires the first app submission to be completed in Partner Center before the GitHub Actions publish flow can take over subsequent updates.

## 1. Partner Center

1. Register a Microsoft Store developer account.
2. Reserve the `HWControl` app name.
3. Open **Product identity** and copy these exact values:
   - Package/Identity/Name
   - Publisher
   - Publisher display name
   - Product ID / Store product ID
4. Create the first submission manually and complete certification. Upload the first `.msix` produced by the package workflow.
5. Configure the Store listing, screenshots, category, age rating, privacy policy, and capabilities.

The package identity values must remain stable for future releases.

## 2. GitHub Actions variables

Create the repository/environment `microsoft-store` and add these **Variables**:

- `STORE_IDENTITY_NAME`
- `STORE_PUBLISHER`
- `STORE_PUBLISHER_DISPLAY_NAME`
- `STORE_PRODUCT_ID`

Use the exact values from Partner Center. Do not substitute a friendly name for the identity or publisher.

## 3. GitHub Actions secrets

For the `microsoft-store` environment, add:

- `AZURE_AD_TENANT_ID`
- `AZURE_AD_APPLICATION_CLIENT_ID`
- `AZURE_AD_APPLICATION_SECRET`
- `SELLER_ID`

The Entra application must have the Partner Center permissions required by the Microsoft Store Developer CLI.

## 4. CI/CD flow

`.github/workflows/store-msix.yml` has two paths:

- `v*` tags: build and validate the Store MSIX and upload it as a GitHub Actions artifact.
- Manual dispatch with `publish=true`: authenticate with Entra ID, package with `msstore`, and publish the update to Microsoft Store.

The publish job passes `STORE_PRODUCT_ID` explicitly, so a local `msstore` configuration file is not required in the repository and Partner Center credentials never need to be committed.

Publishing is intentionally manual so a broken release cannot automatically submit to the public Store.

## 5. Versioning

The Flutter version in `gui_dashboard/pubspec.yaml` is converted to a four-part Store version (`a.b.c.0`). Microsoft Store packages must keep the fourth component at zero.

Example:

```yaml
version: 0.2.3
```

becomes:

```text
0.2.3.0
```

## 6. Architecture

The current Store package targets x64. If ARM64 support is added later, publish an additional architecture package/bundle while preserving the same Store identity.

## 7. Security model

No `.pfx` certificate or private signing key is stored in the repository for Store distribution. Microsoft Store handles signing for packages distributed through the Store. The CI workflow keeps Partner Center credentials in GitHub environment secrets.

The existing GitHub Release MSI/EXE pipeline remains separate; Store publication does not replace the direct-download channel.
