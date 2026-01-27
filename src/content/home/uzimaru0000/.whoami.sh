#!/bin/sh
# Calculate age and display whoami
export CURRENT_YEAR=$(date +%Y)
export CURRENT_MONTH=$(date +%m)
export AGE=$(expr $CURRENT_YEAR - 1998)
test $CURRENT_MONTH -lt 6 && export AGE=$(expr $AGE - 1)
printf "# whoami\n\n![icon](/icon.png?width=120)\n\nHi, I'm **Shuji Oba** (uzimaru) - a %s-year-old software engineer based in Japan.\n\nI love building developer tools and exploring functional programming paradigms.\n\n## Skills\n\n- **Rust** - CLI tools, Git internals, Language implementation\n- **TypeScript / React** - Web frontend, Browser APIs\n- **Elm** - Functional programming, Language processing\n- **Unity / C#** - Game development, Architecture design\n\n## Links\n\n- [GitHub](https://github.com/uzimaru0000)\n- [X (Twitter)](https://x.com/uzimaru0000)\n- [Blog](https://blog.uzimaru.com)\n" $AGE | markdown
