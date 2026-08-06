"""Embedding adapter facade."""

from .providers import EmbeddingProvider, FakeEmbeddingProvider, OpenAIEmbeddingProvider

__all__ = ["EmbeddingProvider", "FakeEmbeddingProvider", "OpenAIEmbeddingProvider"]
