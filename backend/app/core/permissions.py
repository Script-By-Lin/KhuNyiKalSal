"""Role-Based Access Control dependency factories."""

from fastapi import Depends, HTTPException, status

from app.core.security import get_current_user


def require_role(*roles: str):
    """
    Returns a FastAPI dependency that verifies the current user has one of the
    specified roles. Usage: Depends(require_role("user", "organization"))
    Accepts both lowercase and uppercase role strings.
    """
    # Normalise expected roles to uppercase for comparison with RoleEnum values
    normalised_roles = {r.upper() for r in roles}

    async def dependency(current_user=Depends(get_current_user)):
        user_role = current_user.role.value if hasattr(current_user.role, 'value') else str(current_user.role)
        if user_role.upper() not in normalised_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role(s): {', '.join(roles)}",
            )
        return current_user
    return dependency
