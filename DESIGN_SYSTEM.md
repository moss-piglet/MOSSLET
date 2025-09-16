# Mosslet Design System

A modern, calm design system featuring liquid metal aesthetics with teal-to-emerald gradients.

## 🎨 Color Palette

### Primary Gradient

Our signature gradient that defines the brand's liquid metal look:

```css
/* Primary Gradient */
bg-gradient-to-r from-teal-500 to-emerald-500

/* Variations */
from-teal-400 to-emerald-600  /* Darker variant */
from-teal-100 to-emerald-200  /* Light variant */
from-teal-50 to-emerald-100   /* Subtle variant */
```

### Neutral Base

Modern slate tones for backgrounds and text:

```css
/* Light Mode */
slate-50, slate-100, slate-200, slate-300, slate-600, slate-700, slate-900

/* Dark Mode */
slate-600, slate-700, slate-800, slate-900
```

### Semantic Colors

```css
/* Success/Active States */
emerald-500, emerald-600, emerald-700

/* Backgrounds */
slate-50/50 (light), slate-900 (dark)
```

## ✨ Liquid Metal Effects

### Core Principles

1. **Smooth gradients** with subtle transparency layers
2. **Shimmer animations** that sweep across surfaces
3. **Depth through layering** with backdrop blur and shadows
4. **Hardware-accelerated transforms** for 60fps performance

### Shimmer Effect Pattern

```html
<!-- Base liquid background -->
<div
  class="absolute inset-0 opacity-0 transition-all duration-300 ease-out
            bg-gradient-to-r from-teal-50/60 via-emerald-50/80 to-cyan-50/60
            dark:from-teal-900/15 dark:via-emerald-900/20 dark:to-cyan-900/15
            group-hover:opacity-100 transform-gpu"
></div>

<!-- Shimmer sweep -->
<div
  class="absolute inset-0 opacity-0 transition-all duration-500 ease-out
            bg-gradient-to-r from-transparent via-emerald-200/30 to-transparent
            dark:via-emerald-400/15 transform-gpu
            group-hover:opacity-100 group-hover:translate-x-full -translate-x-full"
></div>
```

### Icon Container Pattern

```html
<div
  class="relative flex h-7 w-7 shrink-0 items-center justify-center rounded-lg overflow-hidden
            transition-all duration-200 ease-out transform-gpu will-change-transform
            bg-gradient-to-br from-slate-100 via-slate-50 to-slate-100
            dark:from-slate-700 dark:via-slate-600 dark:to-slate-700
            group-hover:from-teal-100 group-hover:via-emerald-50 group-hover:to-cyan-100
            dark:group-hover:from-teal-900/30 dark:group-hover:via-emerald-900/25 dark:group-hover:to-cyan-900/30"
>
  <!-- Icon content -->
</div>
```

## 🎯 Interactive States

### Hover States

- **Subtle translation**: `hover:translate-x-1` for row-like elements
- **Gentle scaling**: `hover:scale-105` for buttons (use sparingly to avoid layout shift)
- **Color transitions**: Move toward emerald tones
- **Shadow enhancement**: Add soft emerald shadows

### Active States

- **Primary gradient background**: `from-teal-500 to-emerald-600`
- **White text** with drop shadows
- **Pulse animations** for feedback
- **Enhanced shadows** with emerald tinting

### Focus States

```css
focus:outline-none focus:ring-2 focus:ring-emerald-500/50 focus:ring-offset-2
dark:focus:ring-offset-slate-800
```

## 📱 Responsive Design

### Mobile-First Approach

- **Touch-friendly sizing**: Minimum 44px tap targets
- **Full-width rows** on mobile for native feel
- **Generous padding**: `px-6 py-4` for mobile interactive elements

### Desktop Refinements

- **Rounded corners**: `rounded-lg` for buttons and cards
- **Contained padding**: `px-4 py-3` for desktop elements
- **Hover indicators**: Right-edge accents and subtle animations

## 🎬 Animation Guidelines

### Performance Standards

- **Always use `transform-gpu`** for hardware acceleration
- **Add `will-change-transform`** for elements that will animate
- **Duration standards**:
  - Quick feedback: `duration-200` (200ms)
  - Smooth transitions: `duration-300` (300ms)
  - Shimmer effects: `duration-500` (500ms)

### Easing

- **Primary easing**: `ease-out` for natural deceleration
- **Entry animations**: `ease-out`
- **Exit animations**: `ease-in`

### Layout Stability

- **Avoid scaling transforms** that cause layout shifts
- **Use `translate` instead of `scale`** when possible
- **Keep animations contained** within element boundaries

## 🎪 Component Patterns

### Primary Button

```html
<button
  class="inline-flex items-center justify-center rounded-full px-6 py-3
               bg-gradient-to-r from-teal-500 to-emerald-500
               text-sm font-semibold text-white shadow-lg
               hover:scale-105 transform transition-all duration-200
               focus-visible:outline focus-visible:outline-2 
               focus-visible:outline-offset-2 focus-visible:outline-emerald-600"
>
  Button Text
</button>
```

### Card/Panel

```html
<div
  class="rounded-xl bg-white/95 dark:bg-slate-800/95 backdrop-blur-sm
            border border-slate-200/60 dark:border-slate-700/60
            shadow-xl shadow-slate-900/10 dark:shadow-slate-900/30"
>
  <!-- Content -->
</div>
```

### Navigation Row

```html
<a
  class="group relative flex items-center gap-x-3 text-sm font-medium
          px-6 py-4 lg:px-4 lg:py-3 lg:rounded-lg
          transition-all duration-200 ease-out will-change-transform
          overflow-hidden backdrop-blur-sm transform-gpu
          hover:translate-x-1 active:translate-x-0"
>
  <!-- Liquid background and shimmer effects -->
  <!-- Icon and content -->
</a>
```

## 🏗️ Layout Guidelines

### Spacing Scale

- **Tight spacing**: `space-y-0.5`, `gap-2`
- **Normal spacing**: `space-y-1`, `gap-3`
- **Loose spacing**: `space-y-2`, `gap-4`

### Container Padding

- **Mobile**: `px-6`, `py-4`
- **Desktop**: `px-4`, `py-3`
- **Large containers**: `px-8`, `py-6`

### Border Radius

- **Small elements**: `rounded-lg` (8px)
- **Medium elements**: `rounded-xl` (12px)
- **Large panels**: `rounded-2xl` (16px)
- **Buttons**: `rounded-full` for primary actions

## 💡 Best Practices

### Do's

✅ Use the teal-to-emerald gradient consistently  
✅ Layer effects for depth (background + shimmer + shadow)  
✅ Apply hardware acceleration for smooth animations  
✅ Maintain consistent spacing and border radius  
✅ Test in both light and dark modes

### Don'ts

❌ Mix gradient directions inconsistently  
❌ Use scaling transforms that cause layout shifts  
❌ Overuse animations (keep them purposeful)  
❌ Ignore mobile touch targets  
❌ Skip accessibility considerations

## 🎨 Usage Examples

### Sidebar Menu (Reference Implementation)

See `lib/mosslet_web/components/modern_sidebar_menu.ex` for complete liquid metal navigation implementation.

### User Menu Dropdown

See `modern_user_menu/1` in `lib/mosslet_web/components/modern_sidebar_layout.ex` for dropdown styling.

### Interactive Elements

Follow the shimmer and gradient patterns established in the sidebar for consistent liquid metal effects across the application.

---

This design system ensures consistent application of our modern, calm aesthetic with liquid metal effects throughout the Mosslet application.
