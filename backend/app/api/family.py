"""
Family endpoints — group creation, member management (creator-only), relationships, and alert messages.
"""

import uuid as uuid_module
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.account import Account
from app.models.user_profile import UserProfile
from app.models.family import FamilyGroup, FamilyMember, FamilyAlert
from app.core.security import get_current_user
from app.schemas.family import (
    CreateFamilyGroupRequest,
    UpdateFamilyGroupRequest,
    AddFamilyMemberRequest,
    FamilyGroupResponse,
    FamilyMemberResponse,
    FamilyInvitationResponse,
    FamilyAlertResponse,
)
from app.websocket.manager import manager

router = APIRouter()


@router.post("/create", response_model=FamilyGroupResponse)
async def create_family_group(
    data: CreateFamilyGroupRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new Family Group. The creator becomes the Group Admin."""
    # Check if user already belongs to an active family group
    existing_mem = await db.execute(
        select(FamilyMember).where(
            FamilyMember.account_id == current_user.id,
            FamilyMember.status == "accepted",
        )
    )
    if existing_mem.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already an active member of a family group.",
        )

    # Create Group
    group = FamilyGroup(
        group_name=data.group_name.strip(),
        creator_id=current_user.id,
    )
    db.add(group)
    await db.flush()

    # Add creator as primary member
    creator_member = FamilyMember(
        family_id=group.id,
        account_id=current_user.id,
        relationship="Group Creator",
        status="accepted",
    )
    db.add(creator_member)

    # Sync profile family_id
    prof_res = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = prof_res.scalar_one_or_none()
    if profile:
        profile.family_id = str(group.id)

    await db.commit()

    return await _build_group_response(group.id, current_user.id, db)


@router.get("/my-group", response_model=FamilyGroupResponse)
async def get_my_family_group(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetch current user's active family group, members with relationship titles, and creator status."""
    result = await db.execute(
        select(FamilyMember).where(
            FamilyMember.account_id == current_user.id,
            FamilyMember.status == "accepted",
        )
    )
    member_record = result.scalar_one_or_none()
    if not member_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You have not created or joined a family group yet.",
        )

    return await _build_group_response(member_record.family_id, current_user.id, db)


@router.get("/my-invitations", response_model=list[FamilyInvitationResponse])
async def get_my_family_invitations(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetch all pending family invitations for the current user."""
    invitations_res = await db.execute(
        select(FamilyMember, FamilyGroup)
        .join(FamilyGroup, FamilyMember.family_id == FamilyGroup.id)
        .where(
            FamilyMember.account_id == current_user.id,
            FamilyMember.status == "pending",
        )
    )
    rows = invitations_res.all()
    if not rows:
        return []

    creator_ids = [group.creator_id for _, group in rows]
    profiles_res = await db.execute(select(UserProfile).where(UserProfile.account_id.in_(creator_ids)))
    profiles_map = {p.account_id: p for p in profiles_res.scalars().all()}
    accounts_res = await db.execute(select(Account).where(Account.id.in_(creator_ids)))
    accounts_map = {a.id: a for a in accounts_res.scalars().all()}

    result = []
    for member, group in rows:
        prof = profiles_map.get(group.creator_id)
        acc = accounts_map.get(group.creator_id)
        creator_name = prof.full_name if prof else "Family Creator"
        creator_email = acc.email if acc else ""

        result.append(
            FamilyInvitationResponse(
                invitation_id=str(member.id),
                family_id=str(group.id),
                group_name=group.group_name,
                creator_name=creator_name,
                creator_email=creator_email,
                relationship=member.relationship,
                status=member.status,
                created_at=member.added_at,
            )
        )
    return result


@router.post("/invitations/{invitation_id}/accept", response_model=FamilyGroupResponse)
async def accept_family_invitation(
    invitation_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Accept a pending family invitation."""
    try:
        inv_uuid = uuid_module.UUID(invitation_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid invitation ID format")

    res = await db.execute(
        select(FamilyMember).where(
            FamilyMember.id == inv_uuid,
            FamilyMember.account_id == current_user.id,
        )
    )
    member = res.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Family invitation not found")

    if member.status == "accepted":
        return await _build_group_response(member.family_id, current_user.id, db)

    # Check if already accepted another group
    other_accepted = await db.execute(
        select(FamilyMember).where(
            FamilyMember.account_id == current_user.id,
            FamilyMember.status == "accepted",
        )
    )
    if other_accepted.scalar_one_or_none():
        raise HTTPException(
            status_code=400,
            detail="You are already an active member of another family group.",
        )

    member.status = "accepted"

    # Sync user profile family_id
    prof_res = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = prof_res.scalar_one_or_none()
    if profile:
        profile.family_id = str(member.family_id)

    await db.commit()

    # Notify creator via WebSocket
    group_res = await db.execute(select(FamilyGroup).where(FamilyGroup.id == member.family_id))
    group = group_res.scalar_one_or_none()
    if group:
        await manager.send_personal(str(group.creator_id), {
            "event": "FAMILY_INVITATION_ACCEPTED",
            "family_id": str(group.id),
            "member_id": str(current_user.id),
        })

    return await _build_group_response(member.family_id, current_user.id, db)


@router.post("/invitations/{invitation_id}/deny")
async def deny_family_invitation(
    invitation_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Deny/decline a pending family invitation."""
    try:
        inv_uuid = uuid_module.UUID(invitation_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid invitation ID format")

    res = await db.execute(
        select(FamilyMember).where(
            FamilyMember.id == inv_uuid,
            FamilyMember.account_id == current_user.id,
        )
    )
    member = res.scalar_one_or_none()
    if not member:
        raise HTTPException(status_code=404, detail="Family invitation not found")

    family_id = member.family_id
    await db.delete(member)
    await db.commit()

    # Notify creator via WebSocket
    group_res = await db.execute(select(FamilyGroup).where(FamilyGroup.id == family_id))
    group = group_res.scalar_one_or_none()
    if group:
        await manager.send_personal(str(group.creator_id), {
            "event": "FAMILY_INVITATION_DENIED",
            "family_id": str(group.id),
            "member_id": str(current_user.id),
        })

    return {"message": "Family invitation declined successfully."}


@router.post("/add-member", response_model=FamilyGroupResponse)
async def add_family_member(
    data: AddFamilyMemberRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Invite a family member by registered email and relationship (Creator only)."""
    # Fetch current user's family group
    res = await db.execute(
        select(FamilyGroup).where(FamilyGroup.creator_id == current_user.id)
    )
    group = res.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the Family Group Creator can add new family members.",
        )

    # Find target user account by email
    target_email = data.email.lower().strip()
    acc_res = await db.execute(
        select(Account).where(func.lower(Account.email) == target_email)
    )
    target_acc = acc_res.scalar_one_or_none()
    if not target_acc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No user account found with email '{data.email}'. Please ask them to register first.",
        )

    # Check if target is already in a family group (accepted or already invited to this group)
    existing_mem = await db.execute(
        select(FamilyMember).where(
            FamilyMember.account_id == target_acc.id,
            or_(FamilyMember.status == "accepted", FamilyMember.family_id == group.id),
        )
    )
    mem_obj = existing_mem.scalar_one_or_none()
    if mem_obj:
        if mem_obj.status == "pending" and mem_obj.family_id == group.id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"An invitation has already been sent to '{data.email}'.",
            )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User '{data.email}' is already a member of a family group.",
        )

    # Add member with pending invitation status
    new_member = FamilyMember(
        family_id=group.id,
        account_id=target_acc.id,
        relationship=data.relationship,
        status="pending",
    )
    db.add(new_member)
    await db.commit()

    # Real-time WebSocket notification to target user
    try:
        prof_res = await db.execute(select(UserProfile).where(UserProfile.account_id == current_user.id))
        c_prof = prof_res.scalar_one_or_none()
        c_name = c_prof.full_name if c_prof else "Family Creator"

        await manager.send_personal(str(target_acc.id), {
            "event": "FAMILY_INVITATION_RECEIVED",
            "invitation_id": str(new_member.id),
            "family_id": str(group.id),
            "group_name": group.group_name,
            "creator_name": c_name,
            "relationship": data.relationship,
        })
    except Exception:
        pass

    return await _build_group_response(group.id, current_user.id, db)


@router.delete("/members/{member_account_id}", response_model=FamilyGroupResponse)
async def remove_family_member(
    member_account_id: str,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a member from the family group (Creator only)."""
    # Fetch group created by current user
    res = await db.execute(
        select(FamilyGroup).where(FamilyGroup.creator_id == current_user.id)
    )
    group = res.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the Family Group Creator can remove family members.",
        )

    target_uuid = uuid_module.UUID(member_account_id)
    if target_uuid == group.creator_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group creator cannot be removed from the family group.",
        )

    # Find member entry
    mem_res = await db.execute(
        select(FamilyMember).where(
            FamilyMember.family_id == group.id,
            FamilyMember.account_id == target_uuid,
        )
    )
    member_entry = mem_res.scalar_one_or_none()
    if not member_entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Family member not found in your group.",
        )

    await db.delete(member_entry)

    # Clear family_id on user profile
    prof_res = await db.execute(
        select(UserProfile).where(UserProfile.account_id == target_uuid)
    )
    profile = prof_res.scalar_one_or_none()
    if profile:
        profile.family_id = None

    await db.commit()

    return await _build_group_response(group.id, current_user.id, db)


@router.put("/update", response_model=FamilyGroupResponse)
async def update_family_group(
    data: UpdateFamilyGroupRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Update family group name (Creator only)."""
    res = await db.execute(
        select(FamilyGroup).where(FamilyGroup.creator_id == current_user.id)
    )
    group = res.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the Family Group Creator can update the group.",
        )

    group.group_name = data.group_name.strip()
    await db.commit()

    return await _build_group_response(group.id, current_user.id, db)


@router.delete("/group")
async def delete_family_group(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete and disband the family group (Creator only)."""
    res = await db.execute(
        select(FamilyGroup).where(FamilyGroup.creator_id == current_user.id)
    )
    group = res.scalar_one_or_none()
    if not group:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the Family Group Creator can delete the family group.",
        )

    # Clear family_id on UserProfile for all members
    members_res = await db.execute(
        select(FamilyMember).where(FamilyMember.family_id == group.id)
    )
    members = members_res.scalars().all()
    member_acc_ids = [m.account_id for m in members]

    if member_acc_ids:
        profiles_res = await db.execute(
            select(UserProfile).where(UserProfile.account_id.in_(member_acc_ids))
        )
        for profile in profiles_res.scalars().all():
            profile.family_id = None

    await db.delete(group)
    await db.commit()

    return {"detail": "Family group deleted successfully."}


@router.post("/leave")
async def leave_family_group(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Leave the family group (Members only)."""
    res = await db.execute(
        select(FamilyMember).where(FamilyMember.account_id == current_user.id)
    )
    member_entry = res.scalar_one_or_none()
    if not member_entry:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You are not a member of any family group.",
        )

    # Check if user is the creator
    group_res = await db.execute(
        select(FamilyGroup).where(FamilyGroup.id == member_entry.family_id)
    )
    group = group_res.scalar_one_or_none()
    if group and group.creator_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Group creators cannot leave the group. You can delete the group if you wish to disband it.",
        )

    await db.delete(member_entry)

    # Clear family_id on user profile
    prof_res = await db.execute(
        select(UserProfile).where(UserProfile.account_id == current_user.id)
    )
    profile = prof_res.scalar_one_or_none()
    if profile:
        profile.family_id = None

    await db.commit()

    return {"detail": "You have left the family group successfully."}


@router.get("/alerts", response_model=list[FamilyAlertResponse])
async def get_family_alerts(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetch emergency alert message boxes for current user's family group."""
    # Find user's family group
    res = await db.execute(
        select(FamilyMember).where(FamilyMember.account_id == current_user.id)
    )
    member_record = res.scalar_one_or_none()
    if not member_record:
        return []

    # Fetch alerts for this family group
    alerts_res = await db.execute(
        select(FamilyAlert)
        .where(FamilyAlert.family_id == member_record.family_id)
        .order_by(FamilyAlert.created_at.desc())
        .limit(50)
    )
    alerts = alerts_res.scalars().all()

    # Pre-fetch sender names & relationships
    members_res = await db.execute(
        select(FamilyMember).where(FamilyMember.family_id == member_record.family_id)
    )
    rel_map = {m.account_id: m.relationship for m in members_res.scalars().all()}

    # Bulk fetch profiles and accounts for all alert senders to prevent N+1 queries
    sender_ids = list({a.sender_id for a in alerts})
    
    profiles_map = {}
    if sender_ids:
        profiles_res = await db.execute(select(UserProfile).where(UserProfile.account_id.in_(sender_ids)))
        profiles_map = {p.account_id: p for p in profiles_res.scalars().all()}
        
    accounts_map = {}
    if sender_ids:
        accounts_res = await db.execute(select(Account).where(Account.id.in_(sender_ids)))
        accounts_map = {acc.id: acc for acc in accounts_res.scalars().all()}

    output = []
    for a in alerts:
        sender_prof = profiles_map.get(a.sender_id)
        sender_acc = accounts_map.get(a.sender_id)
        
        sender_email = sender_acc.email if sender_acc else ""
        sender_name = sender_prof.full_name if sender_prof else (sender_email or "Family Member")

        output.append(
            FamilyAlertResponse(
                alert_id=str(a.id),
                family_id=str(a.family_id),
                sender_id=str(a.sender_id),
                sender_name=sender_name,
                relationship=rel_map.get(a.sender_id, "Family Member"),
                emergency_id=str(a.emergency_id) if a.emergency_id else None,
                emergency_type=a.emergency_type,
                location_lat=a.location_lat,
                location_lng=a.location_lng,
                message=a.message,
                is_resolved=a.is_resolved,
                created_at=a.created_at,
            )
        )

    return output


async def _build_group_response(
    family_id: uuid_module.UUID, current_user_id: uuid_module.UUID, db: AsyncSession
) -> FamilyGroupResponse:
    group_res = await db.execute(
        select(FamilyGroup).where(FamilyGroup.id == family_id)
    )
    group = group_res.scalar_one_or_none()
    if not group:
        raise HTTPException(status_code=404, detail="Family group not found")

    members_res = await db.execute(
        select(FamilyMember).where(FamilyMember.family_id == family_id)
    )
    members = members_res.scalars().all()

    # Bulk fetch profiles and accounts for all members to prevent N+1 queries
    member_ids = [m.account_id for m in members]
    
    profiles_map = {}
    if member_ids:
        profiles_res = await db.execute(select(UserProfile).where(UserProfile.account_id.in_(member_ids)))
        profiles_map = {p.account_id: p for p in profiles_res.scalars().all()}
        
    accounts_map = {}
    if member_ids:
        accounts_res = await db.execute(select(Account).where(Account.id.in_(member_ids)))
        accounts_map = {acc.id: acc for acc in accounts_res.scalars().all()}

    member_responses = []
    for m in members:
        prof = profiles_map.get(m.account_id)
        full_name = prof.full_name if prof else "Family Member"
        phone = prof.get_decrypted_phone() if prof else ""

        acc = accounts_map.get(m.account_id)
        email = acc.email if acc else ""

        member_responses.append(
            FamilyMemberResponse(
                account_id=str(m.account_id),
                full_name=full_name,
                email=email,
                phone_number=phone,
                relationship=m.relationship,
                is_creator=m.account_id == group.creator_id,
                status=getattr(m, "status", "accepted") or "accepted",
                added_at=m.added_at,
            )
        )

    accepted_members = [m for m in member_responses if m.status == "accepted"]
    pending_members = [m for m in member_responses if m.status == "pending"]

    return FamilyGroupResponse(
        family_id=str(group.id),
        group_name=group.group_name,
        creator_id=str(group.creator_id),
        is_creator=current_user_id == group.creator_id,
        members=accepted_members,
        pending_members=pending_members,
        created_at=group.created_at,
    )
