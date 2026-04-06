# VoiceMind Design Standard

## Purpose

VoiceMind now uses the Apple-flavored design baseline from `awesome-design-md` as the default reference for product UI design.

This standard should guide:
- iOS interface design
- macOS interface design
- Website marketing and product pages
- New design specs, mockups, and UI refactors

## Source Of Truth

- External baseline:
  - [vendor/apple-design-md/DESIGN.md](/Users/cayden/Data/my-data/voiceMind/docs/design/vendor/apple-design-md/DESIGN.md)

## How To Apply In VoiceMind

- Follow Apple-style restraint: fewer visual tricks, stronger hierarchy, cleaner spacing.
- Prefer neutral backgrounds and high-clarity content presentation over decorative gradients and noisy effects.
- Keep interaction accents limited and intentional.
- Use typography to create hierarchy before adding extra UI chrome.
- Make primary actions obvious, but avoid oversized or overly flashy controls unless the page truly needs emphasis.
- For iOS and macOS settings, billing, onboarding, and utility screens:
  - prioritize clarity
  - keep sections compact
  - make status, actions, and legal information easy to scan
- For website and landing content:
  - prefer strong hero framing
  - generous whitespace
  - simple sections with one main message each

## VoiceMind-Specific Constraints

- Preserve existing platform conventions where Apple HIG expectations are stronger than the external reference.
- Billing and subscription pages must always show:
  - plan name
  - duration
  - price
  - restore purchase entry
  - privacy policy
  - terms of use
- When a design decision conflicts with usability, accessibility, or App Store review expectations:
  - prioritize usability and review compliance first
  - use the Apple design baseline second

## Workflow Expectation

- Any future UI redesign or new screen should reference this folder before implementation.
- New design specs in `docs/superpowers/specs` should cite this standard when relevant.
