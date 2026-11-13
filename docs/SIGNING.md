# Signing and notarising OnCue

OnCue's DMG is built on GitHub Actions. With the secrets below set, every build is signed with
your Developer ID, notarised by Apple and stapled, so it opens on any Mac without warnings. A
version tag (`v1.0.0`) publishes it as a GitHub Release, which OnCue's update check offers to
every installed copy. Without the secrets, builds are still made but are only ad-hoc signed, and a
release is refused.

You do these steps once, on your Mac. Never paste the files or passwords into a chat or a commit:
they go only into GitHub's encrypted secrets.

## 1. Developer ID Application certificate

1. Xcode › Settings › Accounts › select your team › **Manage Certificates…**
2. **+** › **Developer ID Application**. (Only the account holder can make one; on an individual
   account that's you.)
3. Open **Keychain Access** › login › My Certificates. Find
   *Developer ID Application: Your Name (TEAMID)*, right-click › **Export…**, save as
   `DeveloperID.p12`, and choose a password.
4. In Terminal: `base64 -i DeveloperID.p12 | pbcopy` (copies it for step 3).

The exact certificate name (`Developer ID Application: Your Name (TEAMID)`) is the
`SIGN_IDENTITY`, and the 10 characters in brackets are the `TEAM_ID`.

## 2. App Store Connect API key (for notarising)

1. appstoreconnect.apple.com › **Users and Access** › **Integrations** › **App Store Connect API** ›
   Team Keys › **+**. Name it "OnCue notarisation", access **Developer**.
2. Download `AuthKey_XXXXXXXXXX.p8` (Apple lets you download it only once). Note the **Key ID**
   and, at the top of the page, the **Issuer ID**.
3. In Terminal: `base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`.

## 3. GitHub secrets

github.com/nishan6/oncue › Settings › Secrets and variables › Actions › **New repository secret**:

| Name | Value |
| --- | --- |
| `DEVELOPER_ID_P12` | the base64 text of DeveloperID.p12 |
| `DEVELOPER_ID_P12_PASSWORD` | the password you chose when exporting |
| `SIGN_IDENTITY` | `Developer ID Application: Your Name (TEAMID)` |
| `TEAM_ID` | the 10-character team id |
| `NOTARY_KEY_P8` | the base64 text of the .p8 key |
| `NOTARY_KEY_ID` | the Key ID |
| `NOTARY_ISSUER` | the Issuer ID |

Secrets aren't visible to anyone who views the public repository, and aren't given to pull
requests from forks.

## 4. Check it

Push any commit (or re-run the latest build). The build's summary on the ci-results branch shows
the DMG step: `Authority=Developer ID Application: …`, `The staple and validate action worked!`
and `source=Notarized Developer ID`.

## 5. Release

`git tag v1.0.0 && git push origin v1.0.0` builds, signs, notarises and publishes the release
with the notes in `docs/release-notes/v1.0.0.md`. Installed copies offer it within 6 hours (or at
once with OnCue › Check for Updates…), never during Live Mode.
