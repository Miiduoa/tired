# Organization Feature Improvements
## Completed: Invitation System (邀請系統)

### 1. Data Model (`Organization.swift`)
- Added `Invitation` struct to support invitation codes.
- Fields: `code` (8-char alphanumeric), `expirationDate`, `maxUses`, `currentUses`, `roleIds`.

### 2. Service Layer (`OrganizationService.swift`)
- **createInvitation**: Generates unique invite codes with optional expiration and usage limits.
- **fetchInvitations**: Allows admins to view active invitations.
- **deleteInvitation**: Allows revoking invitations.
- **joinByInvitationCode**: Transactional logic to verify code, check existing membership, increment usage count, and add user to organization & chat.

### 3. Member Management UI (`MemberManagementView.swift` & VM)
- Added segmented control to switch between "Members" and "Invitations".
- **Invitation List**: Shows active codes, usage stats, and expiration status.
- **Create Invitation**: New sheet to generate codes with "Unlimited", "Single Use", or "Custom" settings.

### 4. Organization Discovery UI (`OrganizationsView.swift` & VM)
- Added "Join by Code" button to the main dashboard.
- Implemented Alert with TextField for easy code entry.
- Connected to backend service for immediate joining.

## Next Steps (Optional)
- **Deep Linking**: Support joining via Universal Links (e.g., `tired://join?code=XYZ`).
- **QR Code**: Display QR code for invitations in the UI.


