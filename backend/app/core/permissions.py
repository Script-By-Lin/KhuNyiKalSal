"""Role-Based Access Control dependency factories."""

from fastapi import Depends, HTTPException, status

from app.core.security import get_current_user


def require_role(*roles: str):
    """
    Returns a FastAPI dependency that verifies the current user has one of the
    specified roles. Usage: Depends(require_role("user", "organization"))
    """
    async def dependency(current_user=Depends(get_current_user)):
        if current_user.role.value not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role(s): {', '.join(roles)}",
            )
        return current_user
    return dependency
