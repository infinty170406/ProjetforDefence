part of guardian_landing;

class _FooterBrand extends StatelessWidget {
  const _FooterBrand({required this.colors});

  final _LandingColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _BrandMark(),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Le centre de contrôle familial qui prolonge votre application parent sur le web.',
            style: TextStyle(
              color: colors.bodyText,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({
    required this.colors,
    required this.title,
    required this.links,
  });

  final _LandingColors colors;
  final String title;
  final List<(String, VoidCallback)> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.text,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 16),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: InkWell(
              onTap: link.$2,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  link.$1,
                  style: TextStyle(
                    color: colors.mutedText,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.child,
    required this.paddingTop,
    required this.paddingBottom,
    required this.horizontalPadding,
  });

  final Widget child;
  final double paddingTop;
  final double paddingBottom;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            paddingTop,
            horizontalPadding,
            paddingBottom,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.colors,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.centered,
    required this.compact,
  });

  final _LandingColors colors;
  final String eyebrow;
  final String title;
  final String description;
  final bool centered;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: Color(0xFF8B7CFF),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 13),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Text(
            title,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: colors.text,
              fontSize: compact ? 34 : 48,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.25,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        const SizedBox(height: 17),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Text(
            description,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: colors.bodyText,
              fontSize: compact ? 14.5 : 16,
              height: 1.62,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF11162A);
    return Semantics(
      label: 'Guardian, accueil',
      button: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6C4DFF), Color(0xFF20D7C5)],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C4DFF).withValues(alpha: 0.24),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Guardian',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  fontFamily: 'Outfit',
                ),
              ),
              Text(
                'FAMILY SAFETY HUB',
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.52),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFB8C2D8)
            : const Color(0xFF4F5A70),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 14),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      dense: true,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Icon(icon, color: const Color(0xFF8B7CFF), size: 21),
      title: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF11162A),
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        size: 13,
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C4DFF), Color(0xFF4C79FF), Color(0xFF20BFB2)],
        ),
        borderRadius: BorderRadius.circular(compact ? 15 : 18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C4DFF).withValues(alpha: 0.26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 17 : 23,
            vertical: compact ? 14 : 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 15 : 18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 12 : 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 9),
              Icon(icon, size: compact ? 17 : 19),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final _LandingColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C4DFF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF8B7CFF).withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF8B7CFF), size: 15),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B7CFF),
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.05,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAssurance extends StatelessWidget {
  const _HeroAssurance({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF20D7C5), size: 17),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            color: isDark ? const Color(0xFFAAB5CB) : const Color(0xFF5A657A),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _FloatingStatusCard extends StatelessWidget {
  const _FloatingStatusCard({
    required this.colors,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final _LandingColors colors;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: colors.floatingCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.colors,
    required this.child,
    required this.radius,
    required this.padding,
  });

  final _LandingColors colors;
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: colors.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: colors.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ProductTab extends StatelessWidget {
  const _ProductTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.colors,
    required this.onTap,
    this.vertical = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final _LandingColors colors;
  final VoidCallback onTap;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 230),
          width: vertical ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: vertical ? 16 : 15,
            vertical: vertical ? 16 : 12,
          ),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF6C4DFF), Color(0xFF4D73F7)],
                  )
                : null,
            color: selected ? null : colors.surface.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? Colors.transparent : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : colors.mutedText,
                size: 19,
              ),
              const SizedBox(width: 10),
              if (vertical)
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : colors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : colors.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (vertical && selected)
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTopBar extends StatelessWidget {
  const _PreviewTopBar({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C4DFF), Color(0xFF20D7C5)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shield_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.more_horiz_rounded,
              color: Colors.white.withValues(alpha: 0.65), size: 19),
        ),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B7CFF), size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _TimelineRule extends StatelessWidget {
  const _TimelineRule({
    required this.time,
    required this.title,
    required this.description,
    required this.color,
  });

  final String time;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              time,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.44),
                    fontSize: 8.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppRuleRow extends StatelessWidget {
  const _AppRuleRow({
    required this.icon,
    required this.name,
    required this.value,
    required this.progress,
    required this.color,
  });

  final IconData icon;
  final String name;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tag,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontSize: 8.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: color,
                  fontSize: 7.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.colors});

  final _LandingColors colors;

  @override
  Widget build(BuildContext context) {
    return _FloatingStatusCard(
      colors: colors,
      icon: Icons.sync_rounded,
      iconColor: const Color(0xFF20D7C5),
      title: 'Synchronisé',
      subtitle: 'Téléphone ↔ Dashboard web',
    );
  }
}

class _ContinuityPoint extends StatelessWidget {
  const _ContinuityPoint({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE2E6F1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF11162A),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9AA7BE)
                        : const Color(0xFF5F6A7E),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.colors,
    required this.moment,
    required this.horizontal,
  });

  final _LandingColors colors;
  final _JourneyMoment moment;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final iconBlock = Container(
      width: horizontal ? 50 : 56,
      height: horizontal ? 50 : 56,
      decoration: BoxDecoration(
        color: moment.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(moment.icon, color: moment.color, size: 25),
    );

    return _HoverLift(
      child: Container(
        padding: const EdgeInsets.all(21),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.border),
        ),
        child: horizontal
            ? Row(
                children: [
                  iconBlock,
                  const SizedBox(width: 16),
                  Expanded(child: _JourneyCopy(colors: colors, moment: moment)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      iconBlock,
                      const Spacer(),
                      Text(
                        moment.time,
                        style: TextStyle(
                          color: moment.color,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  _JourneyCopy(colors: colors, moment: moment, showTime: false),
                ],
              ),
      ),
    );
  }
}

class _JourneyCopy extends StatelessWidget {
  const _JourneyCopy({
    required this.colors,
    required this.moment,
    this.showTime = true,
  });

  final _LandingColors colors;
  final _JourneyMoment moment;
  final bool showTime;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTime) ...[
          Text(
            moment.time,
            style: TextStyle(
              color: moment.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          moment.title,
          style: TextStyle(
            color: colors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          moment.description,
          style: TextStyle(
            color: colors.bodyText,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SecurityPoint extends StatelessWidget {
  const _SecurityPoint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF20D7C5).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF20D7C5), size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF11162A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF9AA7BE)
                      : const Color(0xFF5F6A7E),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  const _PrivacyRow({
    required this.colors,
    required this.icon,
    required this.title,
    required this.value,
    this.last = false,
  });

  final _LandingColors colors;
  final IconData icon;
  final String title;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF8B7CFF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF20D7C5),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverLift extends StatefulWidget {
  const _HoverLift({required this.child, this.offset = 6});

  final Widget child;
  final double offset;

  @override
  State<_HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<_HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -widget.offset : 0, 0),
        child: widget.child,
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({required this.colors});

  final _LandingColors colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          ColoredBox(color: colors.background),
          Positioned(
            left: -220,
            top: -260,
            child: _GlowOrb(
              size: 620,
              color: const Color(0xFF6C4DFF).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            right: -260,
            top: 180,
            child: _GlowOrb(
              size: 660,
              color: const Color(0xFF20D7C5).withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 900,
            child: CustomPaint(
              painter: _GridPainter(
                color: colors.isDark
                    ? Colors.white.withValues(alpha: 0.025)
                    : const Color(0xFF6C4DFF).withValues(alpha: 0.035),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    const step = 54.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LandingColors {
  const _LandingColors(this.isDark);

  final bool isDark;

  Color get background =>
      isDark ? const Color(0xFF030712) : const Color(0xFFF7F8FC);
  Color get sectionTint =>
      isDark ? const Color(0xFF060B17) : const Color(0xFFF0F2F9);
  Color get surface =>
      isDark ? const Color(0xFF0D1424) : const Color(0xFFFFFFFF);
  Color get card => isDark ? const Color(0xFF0B1220) : Colors.white;
  Color get text => isDark ? Colors.white : const Color(0xFF11162A);
  Color get bodyText =>
      isDark ? const Color(0xFFA3AEC3) : const Color(0xFF566176);
  Color get mutedText =>
      isDark ? const Color(0xFF7C889F) : const Color(0xFF7A8498);
  Color get border => isDark
      ? Colors.white.withValues(alpha: 0.085)
      : const Color(0xFFDDE2EE);
  Color get glass => isDark
      ? const Color(0xFF0A1120).withValues(alpha: 0.74)
      : Colors.white.withValues(alpha: 0.78);
  Color get floatingCard => isDark
      ? const Color(0xFF0A1120).withValues(alpha: 0.9)
      : Colors.white.withValues(alpha: 0.92);
  Color get navBackground => isDark
      ? const Color(0xFF070D18).withValues(alpha: 0.92)
      : Colors.white.withValues(alpha: 0.92);
  Color get footer => isDark ? const Color(0xFF02050C) : const Color(0xFFEBEEF6);
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String description;
  final Color accent;
}

class _JourneyMoment {
  const _JourneyMoment({
    required this.time,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final String time;
  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _PlanData {
  const _PlanData({
    required this.name,
    required this.price,
    required this.description,
    required this.features,
    this.popular = false,
  });

  final String name;
  final String price;
  final String description;
  final List<String> features;
  final bool popular;
}

class _FaqData {
  const _FaqData({required this.question, required this.answer});

  final String question;
  final String answer;
}
