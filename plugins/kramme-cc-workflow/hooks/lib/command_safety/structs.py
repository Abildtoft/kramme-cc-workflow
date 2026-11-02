"""Value-object base shared by the parser's result types."""

from __future__ import annotations


class _StructValue:
    """Minimal dataclass replacement: __slots__ plus value equality/repr.

    Avoids `import dataclasses`, which pulls in inspect/dis/tokenize/ast and
    is a measurable fraction of this parser's import cost on every Bash tool
    call. Field order/names must match each subclass's __init__ signature.
    """

    __slots__: tuple[str, ...] = ()

    def __eq__(self, other: object) -> bool:
        if other.__class__ is not self.__class__:
            return NotImplemented
        return all(getattr(self, name) == getattr(other, name) for name in self.__slots__)

    def __repr__(self) -> str:
        fields = ", ".join(f"{name}={getattr(self, name)!r}" for name in self.__slots__)
        return f"{self.__class__.__name__}({fields})"
