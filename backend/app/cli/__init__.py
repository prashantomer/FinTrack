import typer

from app.cli import banks, console, instruments, platforms, seed, term_accounts, transactions, users

app = typer.Typer(help="FinTrack management CLI")

app.add_typer(users.app, name="users")
app.add_typer(banks.app, name="banks")
app.add_typer(platforms.app, name="platforms")
app.add_typer(console.app, name="console")
app.add_typer(instruments.app, name="instruments")
app.add_typer(seed.app, name="seed")
app.add_typer(transactions.app, name="transactions")
app.add_typer(term_accounts.app, name="term-accounts")

if __name__ == "__main__":
    app()
