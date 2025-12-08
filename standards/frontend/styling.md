# Frontend Styling Standards

## Context

CSS, TailwindCSS, and styling patterns for consistent UI development.

## TailwindCSS Guidelines

### Class Organization
Order classes logically:
1. Layout (flex, grid, position)
2. Spacing (margin, padding)
3. Sizing (width, height)
4. Typography (font, text)
5. Visual (bg, border, shadow)
6. Interactive (hover, focus)

```tsx
// Good
<div className="flex items-center gap-4 p-4 w-full text-lg bg-white border rounded-lg hover:shadow-md">

// Avoid: Random order
<div className="bg-white hover:shadow-md flex text-lg p-4 border items-center rounded-lg w-full gap-4">
```

### Component Variants
```tsx
// Use cva or similar for variants
const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-md font-medium transition-colors",
  {
    variants: {
      variant: {
        primary: "bg-blue-600 text-white hover:bg-blue-700",
        secondary: "bg-gray-100 text-gray-900 hover:bg-gray-200",
        ghost: "hover:bg-gray-100"
      },
      size: {
        sm: "h-8 px-3 text-sm",
        md: "h-10 px-4",
        lg: "h-12 px-6 text-lg"
      }
    },
    defaultVariants: {
      variant: "primary",
      size: "md"
    }
  }
);
```

### Responsive Design
```tsx
// Mobile-first approach
<div className="
  flex flex-col gap-2
  md:flex-row md:gap-4
  lg:gap-6
">
```

## CSS Best Practices

### Custom Properties
```css
:root {
  --color-primary: #3b82f6;
  --color-primary-hover: #2563eb;
  --spacing-base: 1rem;
  --radius-default: 0.5rem;
}

.button {
  background: var(--color-primary);
  padding: var(--spacing-base);
  border-radius: var(--radius-default);
}
```

### Naming Conventions (BEM)
```css
/* Block */
.card { }

/* Element */
.card__header { }
.card__body { }

/* Modifier */
.card--featured { }
.card__header--large { }
```

## Component Styling Patterns

### Design Tokens
```tsx
// Define tokens for consistency
const tokens = {
  colors: {
    primary: '#3b82f6',
    secondary: '#6b7280',
    success: '#10b981',
    error: '#ef4444'
  },
  spacing: {
    xs: '0.25rem',
    sm: '0.5rem',
    md: '1rem',
    lg: '1.5rem',
    xl: '2rem'
  },
  borderRadius: {
    sm: '0.25rem',
    md: '0.5rem',
    lg: '1rem',
    full: '9999px'
  }
};
```

### Theme Support
```tsx
// Dark mode with Tailwind
<div className="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">

// CSS custom properties
:root {
  --bg-primary: white;
  --text-primary: #111;
}

[data-theme="dark"] {
  --bg-primary: #111;
  --text-primary: white;
}
```

## Animation Guidelines

### Transitions
```tsx
// Smooth, purposeful transitions
<button className="transition-colors duration-150 ease-in-out hover:bg-blue-600">

// Avoid excessive animation
// Bad: Everything bounces and slides
```

### Motion Preferences
```css
/* Respect user preferences */
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## Layout Patterns

### Container
```tsx
<div className="container mx-auto px-4 max-w-7xl">
  {/* Content */}
</div>
```

### Grid Systems
```tsx
// Responsive grid
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  {items.map(item => <Card key={item.id} {...item} />)}
</div>
```

### Flexbox Patterns
```tsx
// Centered content
<div className="flex items-center justify-center min-h-screen">

// Space between
<div className="flex items-center justify-between">

// Stack with gap
<div className="flex flex-col gap-4">
```

## Icons & Images

### Icon Components
```tsx
// Consistent icon sizing
<Icon className="w-5 h-5" /> // 20px
<Icon className="w-6 h-6" /> // 24px - default
<Icon className="w-8 h-8" /> // 32px
```

### Responsive Images
```tsx
<img
  src={src}
  alt={alt}
  className="w-full h-auto object-cover"
  loading="lazy"
/>
```
