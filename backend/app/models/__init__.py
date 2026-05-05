# Import all models here so SQLAlchemy's mapper registry is fully populated
# before any relationship string references are resolved.
# audit must be LAST — it reads _REGISTRY which is populated by @auditable decorators above.
from app.models.account import Account, AccountType  # noqa: F401
from app.models.bank import Bank  # noqa: F401
from app.models.follio import Follio  # noqa: F401
from app.models.instrument import Instrument, user_instruments  # noqa: F401
from app.models.investment import Investment, InvestmentType  # noqa: F401
from app.models.platform import Platform, PlatformType  # noqa: F401
from app.models.platform_account import PlatformAccount  # noqa: F401
from app.models.term_account import TermAccount, TermAccountType  # noqa: F401
from app.models.transaction import LinkedAccountType, Transaction, TransactionType  # noqa: F401
from app.models.user import User  # noqa: F401
from app.models.audit import AuditLog  # noqa: F401
