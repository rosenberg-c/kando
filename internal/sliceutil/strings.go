package sliceutil

func RemoveString(items []string, remove string) []string {
	for i, item := range items {
		if item == remove {
			return append(items[:i], items[i+1:]...)
		}
	}
	return items
}

func InsertStringAt(items []string, index int, value string) []string {
	items = append(items, "")
	copy(items[index+1:], items[index:])
	items[index] = value
	return items
}
