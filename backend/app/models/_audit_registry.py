_REGISTRY: list[tuple[type, list[str]]] = []


def auditable(*columns: str):
    """Decorator: mark model columns for change auditing."""
    def _wrap(cls):
        _REGISTRY.append((cls, list(columns)))
        return cls
    return _wrap
