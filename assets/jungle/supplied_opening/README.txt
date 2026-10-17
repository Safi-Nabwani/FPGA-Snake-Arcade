Opening Screen Assets for Codex

Files:
1. user_reference_background_126x120.png
   - Small reference image provided by the user.
   - Shows the overall jungle-temple menu composition idea.
   - IMPORTANT: the left sidebar/HUD area is already implemented in the FPGA project and should remain untouched.

2. overgrown_temple_torchlit_frame.png
   - High-resolution art reference for the jungle-temple frame / mood / decorative treatment.
   - Use this mainly as style reference for the right-side opening area.

3. snake_arcade_temple_menu.png
   - High-resolution concept for the opening screen content area.
   - Use this as the main visual/layout reference for the right-side opening area while preserving the existing implemented sidebar on the left.

Implementation intent:
- Keep the current left sidebar exactly as implemented in the project.
- Only replace / implement the opening-screen graphics in the remaining screen area to the right of the sidebar.
- Prefer the most memory-efficient implementation possible.
- Reuse / crop / scale these supplied assets as needed; do not generate new artwork.