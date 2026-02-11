package com.zlatoapps.baehub

import android.net.Uri
import android.os.Bundle
import android.view.View
import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web/list")
class ListWebFragment : HotwireWebFragment() {

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        setupFilterMenu()
    }

    private fun setupFilterMenu() {
        val toolbar = toolbarForNavigation() ?: return
        toolbar.inflateMenu(R.menu.menu_filter)
        toolbar.setOnMenuItemClickListener { item ->
            if (item.itemId == R.id.action_filter) {
                navigateToFilter()
                true
            } else {
                false
            }
        }
    }

    private fun navigateToFilter() {
        val filterUrl = filterUrl(location) ?: return
        navigator.route(filterUrl)
    }

    private fun filterUrl(location: String): String? {
        val uri = Uri.parse(location)
        val path = uri.path ?: return null
        val normalizedPath = if (path.length > 1) path.trimEnd('/') else path

        val basePath = when (normalizedPath) {
            "/tasks" -> "/tasks/filters"
            "/events" -> "/events/filters"
            "/expenses" -> "/expenses/filters"
            else -> return null
        }

        val baseUrl = "${uri.scheme}://${uri.authority}"
        val query = uri.query
        return if (query.isNullOrEmpty()) {
            "$baseUrl$basePath"
        } else {
            "$baseUrl$basePath?$query"
        }
    }
}
