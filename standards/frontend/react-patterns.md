# React Patterns & Best Practices

## Context

Frontend standards for React applications. Apply when building UI components.

## Component Structure

### Functional Components
```tsx
// Preferred: Functional components with hooks
interface UserCardProps {
  user: User;
  onSelect?: (user: User) => void;
}

export function UserCard({ user, onSelect }: UserCardProps) {
  const handleClick = () => onSelect?.(user);

  return (
    <div className="user-card" onClick={handleClick}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
}
```

### Component Organization
```
components/
├── ui/                    # Generic UI components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   └── index.ts
│   └── Input/
├── features/              # Feature-specific components
│   ├── auth/
│   └── dashboard/
└── layouts/               # Layout components
    ├── MainLayout.tsx
    └── AuthLayout.tsx
```

## State Management

### Local State
```tsx
// Simple local state
const [isOpen, setIsOpen] = useState(false);

// Complex local state
const [form, setForm] = useReducer(formReducer, initialState);
```

### Server State (React Query)
```tsx
// Data fetching
const { data, isLoading, error } = useQuery({
  queryKey: ['users', userId],
  queryFn: () => fetchUser(userId)
});

// Mutations
const mutation = useMutation({
  mutationFn: updateUser,
  onSuccess: () => queryClient.invalidateQueries(['users'])
});
```

### Global State (Zustand)
```tsx
// Store definition
const useStore = create<Store>((set) => ({
  theme: 'light',
  setTheme: (theme) => set({ theme })
}));

// Usage
const theme = useStore((state) => state.theme);
```

## Hooks Best Practices

### Custom Hooks
```tsx
// Extract reusable logic into hooks
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}
```

### Hook Rules
- Only call hooks at the top level
- Only call hooks from React functions
- Use `use` prefix for custom hooks
- Keep hooks focused on single concern

## Performance

### Memoization
```tsx
// Memoize expensive components
const ExpensiveList = memo(function ExpensiveList({ items }: Props) {
  return items.map(item => <Item key={item.id} {...item} />);
});

// Memoize callbacks
const handleSubmit = useCallback(() => {
  submitForm(formData);
}, [formData]);

// Memoize computed values
const sortedItems = useMemo(
  () => items.sort((a, b) => a.name.localeCompare(b.name)),
  [items]
);
```

### Code Splitting
```tsx
// Lazy load routes/heavy components
const Dashboard = lazy(() => import('./pages/Dashboard'));

function App() {
  return (
    <Suspense fallback={<Loading />}>
      <Dashboard />
    </Suspense>
  );
}
```

## Event Handling

### Event Types
```tsx
// Form events
const handleChange = (e: ChangeEvent<HTMLInputElement>) => {
  setName(e.target.value);
};

// Mouse events
const handleClick = (e: MouseEvent<HTMLButtonElement>) => {
  e.preventDefault();
  doSomething();
};
```

### Event Delegation
```tsx
// Handle events at parent level when appropriate
function List({ items, onItemClick }: Props) {
  const handleClick = (e: MouseEvent) => {
    const id = (e.target as HTMLElement).dataset.id;
    if (id) onItemClick(id);
  };

  return (
    <ul onClick={handleClick}>
      {items.map(item => (
        <li key={item.id} data-id={item.id}>{item.name}</li>
      ))}
    </ul>
  );
}
```

## Error Handling

### Error Boundaries
```tsx
class ErrorBoundary extends Component<Props, State> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    logError(error, info);
  }

  render() {
    if (this.state.hasError) {
      return <ErrorFallback onRetry={() => this.setState({ hasError: false })} />;
    }
    return this.props.children;
  }
}
```

## Accessibility

### ARIA Labels
```tsx
<button
  aria-label="Close dialog"
  aria-pressed={isPressed}
  onClick={handleClose}
>
  <XIcon />
</button>
```

### Keyboard Navigation
```tsx
function handleKeyDown(e: KeyboardEvent) {
  switch (e.key) {
    case 'Enter':
    case ' ':
      handleSelect();
      break;
    case 'Escape':
      handleClose();
      break;
  }
}
```
