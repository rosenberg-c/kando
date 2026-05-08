package kanban

import "kando/server/internal/sliceutil"

// ReorderIDs returns a reordered copy where targetID is moved to destinationPosition.
func ReorderIDs(ids []string, targetID string, destinationPosition int) ([]string, error) {
	if destinationPosition < 0 {
		return nil, ErrInvalidInput
	}

	copied := append([]string(nil), ids...)
	withoutTarget := sliceutil.RemoveString(copied, targetID)
	if len(withoutTarget) != len(ids)-1 {
		return nil, ErrNotFound
	}
	if destinationPosition > len(withoutTarget) {
		return nil, ErrInvalidInput
	}

	return sliceutil.InsertStringAt(withoutTarget, destinationPosition, targetID), nil
}

// ValidateExactOrder verifies candidateIDs contains exactly the same IDs as currentIDs, once each.
func ValidateExactOrder(currentIDs, candidateIDs []string) error {
	if len(currentIDs) != len(candidateIDs) {
		return ErrInvalidInput
	}

	seen := make(map[string]struct{}, len(candidateIDs))
	for _, id := range candidateIDs {
		if id == "" {
			return ErrInvalidInput
		}
		if _, exists := seen[id]; exists {
			return ErrInvalidInput
		}
		seen[id] = struct{}{}
	}

	for _, id := range currentIDs {
		if _, ok := seen[id]; !ok {
			return ErrInvalidInput
		}
	}

	return nil
}
