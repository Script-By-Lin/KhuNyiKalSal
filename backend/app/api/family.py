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
    AddFamilyMemberRequest,
    FamilyGroupResponse,
    FamilyMemberResponse,
    FamilyAlertResponse,
)

router = APIRouter()


@router.post("/create", response_model=FamilyGroupResponse)
async def create_family_group(
    data: CreateFamilyGroupRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a new Family Group. The creator becomes the Group Admin."""
    # Check if user already belongs to a family group
    existing_mem = await db.execute(
        select(FamilyMember).where(FamilyMember.account_id == current_user.id)
    )
    if existing_mem.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You are already a member of a family group.",
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
    )
    db.add(creator_member)
    await db.commit()

    return await _build_group_response(group.id, current_user.id, db)


@router.get("/my-group", response_model=FamilyGroupResponse)
async def get_my_family_group(
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Fetch current user's family group, members with relationship titles, and creator status."""
    result = await db.execute(
        select(FamilyMember).where(FamilyMember.account_id == current_user.id)
    )
    member_record = result.scalar_one_or_none()
    if not member_record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="You have not created or joined a family group yet.",
        )

    return await _build_group_response(member_record.family_id, current_user.id, db)


@router.post("/add-member", response_model=FamilyGroupResponse)
async def add_family_member(
    data: AddFamilyMemberRequest,
    current_user: Account = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a family member by registered email and relationship (Creator only)."""
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

    # Check if target is already in a family group
    existing_mem = await db.execute(
        select(FamilyMember).where(FamilyMember.account_id == target_acc.id)
    )
    if existing_mem.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"User '{data.email}' is already a member of another family group.",
        )

    # Add member
    new_member = FamilyMember(
        family_id=group.id,
        account_id=target_acc.id,
        relationship=data.relationship,
    )
    db.add(new_member)

    # Also sync family_id string on user profile if available
    prof_res = await db.execute(
        select(UserProfile).where(UserProfile.account_id == target_acc.id)
    )
    profile = prof_res.scalar_one_or_none()
    if profile:
        profile.family_id = str(group.id)

    await db.commit()

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
                added_at=m.added_at,
            )
        )

    return FamilyGroupResponse(
        family_id=str(group.id),
        group_name=group.group_name,
        creator_id=str(group.creator_id),
        is_creator=current_user_id == group.creator_id,
        members=member_responses,
        created_at=group.created_at,
    )
