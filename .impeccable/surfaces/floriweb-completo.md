---
version: 1
slug: "floriweb-completo"
primary_target: "src/App.tsx"
related_targets: ["src/layouts/AdminLayout.tsx","src/layouts/StoreLayout.tsx","src/layouts/MasterLayout.tsx","src/pages/admin/Dashboard.tsx","src/pages/admin/Onboarding.tsx","src/pages/admin/Analytics.tsx","src/pages/admin/Products.tsx","src/pages/admin/ProductForm.tsx","src/pages/admin/Categories.tsx","src/pages/admin/Addons.tsx","src/pages/admin/Orders.tsx","src/pages/admin/DeliveryZones.tsx","src/pages/admin/Settings.tsx","src/pages/admin/Plan.tsx","src/pages/store/Home.tsx","src/pages/store/ProductDetail.tsx","src/pages/store/Cart.tsx","src/pages/store/Checkout.tsx","src/pages/store/OrderSuccess.tsx","src/pages/master/Dashboard.tsx","src/pages/master/Stores.tsx","src/pages/master/Plans.tsx","src/pages/master/Diagnostics.tsx","src/pages/master/Mfa.tsx","src/components/ProductCard.tsx","src/components/StoreHeader.tsx","src/components/ui/TurnstileWidget.tsx","src/styles.css"]
---

# FloriWeb full visual pass

This is one product-wide refinement pass. Preserve the current product world from PRODUCT.md and DESIGN.md. Do not redesign the architecture or business behavior.

## Surface modes

- Admin and Admin Master: Operate. Fast scanning, clear state, compact but breathable density, strong keyboard/focus behavior, no decorative dashboard noise.
- Storefront: Persuade plus light Operate. Product imagery and buying confidence lead; conversion must stay obvious on mobile without becoming a marketing landing page.
- Checkout: Operate with trust. Reduce anxiety, group information clearly, keep total and primary action visible, and integrate Turnstile without making it look like an error state.
- Auth, first access and MFA: Operate. Calm, secure, minimal, professional.

## Product-wide visual goals

1. Make the application look intentionally designed for florists, not like a generic SaaS template.
2. Keep the warm off-white + deep green direction and the editorial serif contrast only where it improves commerce.
3. Reduce card soup, nested borders, redundant headings, weak gray text and equal visual weight everywhere.
4. Align spacing, radii, input heights, button sizes, icon weight and typography across the whole product.
5. Make primary actions identifiable within three seconds on every screen.
6. Make empty, loading, error, disabled, success and permission states feel part of the same system.
7. Keep contrast, focus rings, labels and touch targets production-grade.

## Admin

- Sidebar/navigation must remain easy to scan in 1366x768 and not dominate the content.
- Dashboard must show readiness, current store state and the next useful action above the fold where possible.
- Onboarding should feel like a short activation path, not a settings checklist dump.
- Product/category/addon/order/settings screens should share table/form spacing, headings, actions and empty states.
- Dense operational screens should use separators and alignment before adding more cards or shadows.

## Storefront

- Product image and product name are the strongest visual content.
- Category navigation should be easy with one hand on 390x844.
- Product cards should have consistent image ratios, price hierarchy and clear add/detail behavior.
- The mobile cart dock must remain visible without covering important content.
- Avoid generic hero sections, excessive badges and decorative copy that delays catalog discovery.

## Checkout

- The customer must always understand where they are, what is required and what the final amount is.
- Group customer, fulfillment, recipient, payment, card message and review information with clear progressive hierarchy.
- Sticky mobile CTA must not cover fields, validation feedback, Turnstile or browser safe areas.
- Keep privacy copy short and specific.
- Preserve all submit handlers, Turnstile behavior, server validation and draft privacy rules exactly.

## Admin Master

- Treat as a commercial cockpit: paying clients, demos, onboarding, attention and suspended stores.
- Filters and status signals should answer who needs action now.
- Metrics should be useful without turning the page into a wall of cards.
- Store management forms must remain operationally clear and MFA/security context should feel deliberate.

## Viewports and QA

Mandatory representative sizes:
- desktop: 1366x768;
- mobile: 390x844;
- also sanity-check an intermediate width around 768-1024px.

No horizontal scrolling. No clipped sticky controls. No fixed element may hide primary content or Turnstile.

## Functional freeze

Visual work may edit TSX structure/classes and CSS, but must not change:
- routes or route parameters;
- service/API calls;
- Supabase/Auth/MFA logic;
- useEffect data-fetching behavior;
- submit handlers, prices, order payloads or payment/delivery logic;
- analytics event semantics;
- Turnstile behavior;
- environment variables, wrangler, Edge Functions or supabase/**;
- plan entitlements or multi-store isolation.

If a visual improvement requires any functional change, report it separately and do not implement it in this pass.
